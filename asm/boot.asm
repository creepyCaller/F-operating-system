org 7c00h
mov ax, cs
mov ds, ax
mov es, ax
call DispStr
jmp $
DispStr:
    mov ax, BootMsg
    mov bp, ax
    mov cx, 15
    mov ax, 1301h
    mov bx, 000fh
    mov dl, 0
    int 10h
    ret
BootMsg:
	db "Hello, world !"
times 510 - ($ - $$) db 0
dw 0xaa55
