;==============================================
;   This file is part of ASMTP.
;
;   ASMTP is free software: you can redistribute it and/or modify
;   it under the terms of the GNU General Public License as published by
;   the Free Software Foundation, either version 3 of the License, or
;   (at your option) any later version.
;
;   ASMTP is distributed in the hope that it will be useful,
;   but WITHOUT ANY WARRANTY; without even the implied warranty of
;   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;   GNU General Public License for more details.
;
;   You should have received a copy of the GNU General Public License
;   along with ASMTP.  If not, see <http://www.gnu.org/licenses/>.
;
;=============================================

global _start

%include 'data.inc'
%include 'funcs.inc'

section .text 

jmp _start

error:          ;called if there is an error. TODO: Make this take arguments and output more appropriate error messages.
    pusha
    mov edx, Errormsg_len
    mov ecx, Errormsg
    mov ebx, 1
    mov eax, 4
    int 80h

    jmp exit
     


;===Entry Point======================================



_start:


    

;    mov eax, SYS_FORK ;fork the process.  
;    xor ebx, ebx
;    xor ecx, ecx
;    xor edx, edx
;    int 80h
   
    pusha
    xor ecx, ecx
    mov edx, Startmsg_len ;write message
    mov ecx, Startmsg
    mov ebx, 1
    mov eax, 4
    int 80h
    popa    
    
 
open_socket:
    
   

    push     IPPROTO_TCP  ;push arguments for sys_socketcall
    push     SOCK_STREAM 
    push     AF_INET
    
    mov eax, SYS_SOCKETCALL ;int 80h param = sys_socketcall
    mov ebx, SYS_SOCK_SOCKET ;argument for sys_socketcall is sub function sys_socket
    mov ecx, esp ;also pass pointer to the other args on the stack
    int 80h

    mov edx, eax ; move socket file desc to edx
    mov [sock_desc], edx

    cmp eax, -1 ; make sure that we didnt error.
    je error
           
   
 
bind_socket:

    xor eax, eax ; make sure registers are void. We might not need this.
    xor ebx, ebx    

    
    push WORD INADDR_ANY    ; push the socket type
    mov ax, PORT            ;move port number and push it around a bit.
    xchg al, ah             ;I think this converts it into network byte order. But I'm not sure, and it works. So eh.
    push eax                ;Push arguments
    push WORD AF_INET
    mov ecx, esp ;
    
    mov eax, SYS_SOCKETCALL ;socket call
    mov ebx, SYS_SOCK_BIND    ;bind socket

    push 16                 ;push sizeof(args)
    push ecx                ;push pointer to args
    mov edx, [sock_desc]    ;make edx = socket descriptor
    push edx                ;push it

    mov ecx, esp            ;point to args
    int 80h                 ;call kernel

    cmp eax, -1             ;if error
    je error                ;goto error.

listen:
    
    push 0                  ;push args
    push edx

    mov eax, SYS_SOCKETCALL   ;socketcall           
%define PORT               25

%define LISTEN_LIMIT       30
    mov ebx, SYS_SOCK_LISTEN  ;sock listen
    mov ecx, esp              ;push pointer to args
      
    int 80h                   ;Hello? Is the Kernel?
        
    cmp eax, 0                ;Check for errors
    jne error                 

accept:
    
    mov eax, SYS_SOCKETCALL ;Socket call
    mov ebx, SYS_SOCK_ACCEPT;socket accept    

    push 0                  ;We dont need any info, but we still need to pass all args
    push 0                      
    push edx                ;push  File descriptor
    mov ecx, esp            ;make ecx point to arguments
    int 80h                 ;Telephone Mr Kernel

    mov edx, eax            ;save result in edx

greet:
    
    mov esi, CMD_220        ;point esi to string we're moving
    mov edi, send_buffer      ;point edi to where we're moving it to.
    mov ecx, CMD_220_len    ;make ecx = the length of the string
    rep movsb               ;move bytes pointed to by esi to address pointed to by edi
                            ;repeat for lengh of string.
    
    
    add edi, ecx            ; increase count in edi (We're appending the cmd_buffer)
    mov esi, Domain         ; make esi point to Domain string
    mov ecx, Domain_len     ; Make ecx = the length of the string
    rep movsb               ; Move bytes. repeat for length of string

                            ;send_buffer should now equal something like "220 [domain]


    pusha
    xor ecx, ecx
    mov edx, SIZE_OF_SEND_BUFF ; show message cmd buff contents
    mov ecx, send_buffer
    mov ebx, 1
    mov eax, 4
    int 80h
    popa    
    
send: 
    
    push 0                  ;flags arg (not required)
    push SIZE_OF_SEND_BUFF   ;push arguments
    push send_buffer
    ;mov edx, [sock_desc]
    push edx
    
    mov ecx, esp            ;save pointer to args
    mov eax, SYS_SOCKETCALL  ; select sys calls.
    mov ebx, SYS_SOCK_SEND
    int 80h                 ;ring ring
   

    pusha
    xor ecx, ecx
    mov edx, SIZE_OF_REC_BUFF ;write message
    mov ecx, rec_buffer
    mov ebx, 1
    mov eax, 4
    int 80h
    popa    
    
    
recv:
    mov eax, SYS_SOCKETCALL 
    mov ebx, SYS_SOCK_RECV

    push 0
    push SIZE_OF_REC_BUFF
    push rec_buffer
    push edx
    
    mov ecx, esp
    int 80h
    
    cmp eax, 0
    jg start_talking ;If the connection has been made, Lets get going!
    jl error ; else, we should error.

    pusha
    xor ecx, ecx
    mov edx, SIZE_OF_REC_BUFF ;write message
    mov ecx, rec_buffer
    mov ebx, 1
    mov eax, 4
    int 80h
    popa    


start_talking:

    mov al, '2'
    mov ebx, rec_buffer
    mov ah, BYTE [ebx]
    cmp ah, al
    ;jne error
    
    mov al, '2'
    mov ah, BYTE [ebx+1]
    cmp ah, al
    ;jne error
    
    mov al, '0'
    mov ah, BYTE [ebx+2]
    cmp ah, al
    ;jne error

    ;mov eax, '2'
    ;mov ebx, [rec_buffer+1]
    ;cmp eax, ebx
    ;jne error
    ;mov eax, '0'
    ;mov ebx, [rec_buffer+2]
    ;cmp eax, ebx
    ;jne error


    pusha
    xor ecx, ecx
    mov edx, SIZE_OF_REC_BUFF ;write message
    mov ecx, rec_buffer
    mov ebx, 1
    mov eax, 4
    int 80h
    popa    


     
exit:    
    mov eax, SYS_EXIT ;call exit system call. 
    mov ebx, 0
    int 80h

    
     

