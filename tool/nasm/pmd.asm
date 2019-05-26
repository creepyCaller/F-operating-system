%include	"pm.inc"

org	0100h
	jmp	LABEL_BEGIN

[SECTION .gdt]
; global descriptor table
; GDT descriptor
LABEL_GDT:			Descriptor	0, 0, 0
LABEL_DESC_NORMAL:	Descriptor	0, 0ffffh, DA_DRW
LABEL_DESC_CODE16:	Descriptor	0, 0ffffh, DA_C
LABEL_DESC_CODE32:	Descriptor	0, SegCode32Len - 1, DA_C + DA_32
LABEL_DESC_DATA:	Descriptor	0, DataLen - 1, DA_DRW
LABEL_DESC_STACK:	Descriptor	0, TopOfStack, DA_DRWA + DA_32
LABEL_DESC_VIDEO:	Descriptor	0B8000h, 0ffffh, DA_DRW
LABEL_DESC_LDT:		Descriptor	0, LDTLen - 1, DA_LDT

LABEL_DESC_CODE_DEST: Descriptor 0, SegCodeDestLen - 1, DA_C + DA_32
LABEL_CALL_GATE_TEST: Gate SelectorCodeDest, 0, 0, DA_386CGate + DA_DPL0 ;调用门测试

GdtLen	equ	$ - LABEL_GDT ; 长度

; GDT selector
SelectorNormal	equ	LABEL_DESC_NORMAL - LABEL_GDT
SelectorCode16	equ	LABEL_DESC_CODE16 - LABEL_GDT
SelectorCode32	equ	LABEL_DESC_CODE32 - LABEL_GDT
SelectorData	equ	LABEL_DESC_DATA - LABEL_GDT
SelectorStack	equ	LABEL_DESC_STACK - LABEL_GDT
SelectorVideo	equ	LABEL_DESC_VIDEO - LABEL_GDT
SelectorLDT		equ	LABEL_DESC_LDT - LABEL_GDT

SelectorCodeDest equ LABEL_DESC_CODE_DEST - LABEL_GDT
SelectorCallGateTest equ LABEL_CALL_GATE_TEST - LABEL_GDT ;调用门对应的选择子

GdtPtr	dw	GdtLen - 1 ; 界限
		dd	0 ; 基地址
; END of [SECTION .gdt]

[SECTION .ldt]
; local descriptor table
ALIGN	32
; LDT descriptor
LABEL_LDT:
LABEL_LDT_DESC_CODEA:	Descriptor	0, CodeALen - 1, DA_C + DA_32

LDTLen	equ	$ - LABEL_LDT

; LDT selector
SelectorLDTCodeA:	equ	LABEL_LDT_DESC_CODEA - LABEL_LDT + SA_TIL
; END of [SECTION .ldt]

[SECTION .data1] ; test strings
ALIGN	32
[BITS 32]
LABEL_DATA:
SPValueInRealMode	dw	0
PMMessage:			db	"NOW IN PROTECT MODE.", 0
OffsetPMMessage		equ	PMMessage - $$
DataLen				equ	$ - LABEL_DATA
; END of [SECTION .data1]

[SECTION .gs] ; global stack
ALIGN	32
[BITS 32]
LABEL_STACK:
	times 512 db 0
	
TopOfStack	equ	$ - LABEL_STACK - 1
; END of [SECTION .gs]

[SECTION .s16]
[BITS 16]
LABEL_BEGIN:
	mov ax, cs
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	mov	sp, 0100h
	
	mov	[LABEL_GO_BACK_TO_REAL+3], ax
	mov	[SPValueInRealMode], sp

	; 初始化 16 位代码段描述符
	mov	ax, cs
	movzx eax, ax
	shl	eax, 4
	add	eax, LABEL_SEG_CODE16
	mov	word [LABEL_DESC_CODE16 + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_CODE16 + 4], al
	mov	byte [LABEL_DESC_CODE16 + 7], ah

	; 初始化 32 位代码段描述符
	xor	eax, eax
	mov	ax, cs
	shl	eax, 4
	add	eax, LABEL_SEG_CODE32
	mov	word [LABEL_DESC_CODE32 + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_CODE32 + 4], al
	mov	byte [LABEL_DESC_CODE32 + 7], ah

	; 初始化数据段描述符
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_DATA
	mov	word [LABEL_DESC_DATA + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_DATA + 4], al
	mov	byte [LABEL_DESC_DATA + 7], ah

	; 初始化堆栈段描述符
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_STACK
	mov	word [LABEL_DESC_STACK + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_STACK + 4], al
	mov	byte [LABEL_DESC_STACK + 7], ah
	
	; 初始化 LDT 在 GDT 中的描述符
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_LDT
	mov	word [LABEL_DESC_LDT + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_LDT + 4], al
	mov	byte [LABEL_DESC_LDT + 7], ah

	; 初始化 LDT 中的描述符
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_CODE_A
	mov	word [LABEL_LDT_DESC_CODEA + 2], ax
	shr	eax, 16
	mov	byte [LABEL_LDT_DESC_CODEA + 4], al
	mov	byte [LABEL_LDT_DESC_CODEA + 7], ah
	
	;初始化测试调用门的代码段描述符
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_SEG_CODE_DEST
	mov	word [LABEL_DESC_CODE_DEST + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_CODE_DEST + 4], al
	mov	byte [LABEL_DESC_CODE_DEST + 7], ah
	
	; 为加载 GDTR 作准备
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_GDT		; eax <- gdt 基地址
	mov	dword [GdtPtr + 2], eax	; [GdtPtr + 2] <- gdt 基地址

	; 加载 GDTR
	lgdt	[GdtPtr]

	; 关中断
	cli
	
	; 打开地址线A20
	in	al, 92h
	or	al, 00000010b
	out	92h, al ; 修改92h端口
	
	; 设置寄存器cr0的第0位(PE位)为1
	mov	eax, cr0
	or	eax, 1
	mov	cr0, eax
	
	; 把32位代码段的选择子装入cs
	jmp	dword SelectorCode32:0 ; 因为jmp目标地址为32位, 所以需要加一个DWORD向编译器说明, 不然偏移高位会被截断
	
LABEL_REAL_ENTRY: ; 从保护模式跳回到实模式就到了这里(实模式入口)
	mov	ax, cs
	mov	ds, ax
	mov	es, ax
	mov	ss, ax

	mov	sp, [SPValueInRealMode]

	in	al, 92h ; 关闭 A20 地址线
	and	al, 11111101b
	out	92h, al

	sti; 开中断

	mov	ax, 4c00h ; 返回DOS
	int	21h
; END of [SECTION .s16]

[SECTION .s32]
[BITS 32]
LABEL_SEG_CODE32:
	; 加载段至段寄存器
	mov ax, SelectorData
	mov ds, ax ; data segment
	
	mov ax, SelectorVideo
	mov gs, ax ; global section
	
	mov ax, SelectorStack
	mov ss, ax ; stack segment
	
	mov esp, TopOfStack
	
	; 这里到段结束是主要执行的代码段
	mov ah, 00000111b
	xor esi, esi
	xor edi, edi
	mov esi, OffsetPMMessage ; 在第10行输出 "NOW IN PROTECT MODE."
	mov edi, (80 * 10 + 0) * 2
	cld
.1:
	lodsb
	test al, al
	jz .2
	mov [gs:edi], ax
	add edi, 2
	jmp .1
.2:
	call DispReturn ; 输出回车
	
	call SelectorCallGateTest:0
	
	; 加载ldt
	mov ax, SelectorLDT
	lldt ax
	
	jmp	SelectorLDTCodeA:0

DispReturn:
	push eax
	push ebx
	mov eax, edi
	mov bl, 160
	div bl
	and eax, 000000FFh
	inc eax
	mov bl, 160
	mul bl
	mov edi, eax
	pop ebx
	pop eax
	
	ret
	
SegCode32Len	equ	$ - LABEL_SEG_CODE32
; END of [SECTION .s32]

[SECTION .sdest]
[BITS 32]
LABEL_SEG_CODE_DEST:
	mov ax, SelectorVideo
	mov gs, ax
	
	mov edi, (80 * 12 + 0) * 2
	mov ah, 00000111b
	mov al, 'J'
	mov [gs:edi], ax

	retf
	
SegCodeDestLen	equ	$ - LABEL_SEG_CODE_DEST
; END of [SECTION .sdest]

[SECTION .s16code]
ALIGN 32
[BITS 16]
LABEL_SEG_CODE16:
	; 跳回实模式
	mov ax, SelectorNormal
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	mov ss, ax
	
	mov eax, cr0
	and al, 11111110b
	mov cr0, eax
	
LABEL_GO_BACK_TO_REAL:
	jmp	0:LABEL_REAL_ENTRY

Code16Len	equ	$ - LABEL_SEG_CODE16
; END of [SECTION .s16code]

[SECTION .la]
ALIGN 32
[BITS 32]
LABEL_CODE_A:
	mov ax, SelectorVideo
	mov gs, ax
	
	mov edi, (80 * 11 + 0) * 2
	mov ah, 00000111b
	mov al, 'L'
	mov [gs:edi], ax
	
	jmp SelectorCode16:0
	
CodeALen	equ	$ - LABEL_CODE_A
; END of [SECTION .la]
