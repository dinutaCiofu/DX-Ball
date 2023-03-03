.386
.model flat, stdcall
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;includem biblioteci, si declaram ce functii vrem sa importam
includelib msvcrt.lib
extern exit: proc
extern malloc: proc
extern memset: proc
extern printf: proc

includelib canvas.lib
extern BeginDrawing: proc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;declaram simbolul start ca public - de acolo incepe executia
public start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;sectiunile programului, date, respectiv cod
.data
;aici declaram date
window_title DB "DX-BALL",0
area_width EQU 640
area_height EQU 480
area DD 0

counter DD 0 ; numara evenimentele de tip timer


;detalii minge
ball_x dd 310
ball_y dd 430
ball_size dd 20

;detalii paleta
p_width equ 100
p_height equ 15
p_x dd 240
p_y dd 455

click_button dd 0 ;daca s-a dat click pe play = 1, 0 in caz contrar

arg1 EQU 8
arg2 EQU 12
arg3 EQU 16
arg4 EQU 20

symbol_width EQU 10
symbol_height EQU 20

;detalii bonus
bonus_width equ 24
bonus_height equ 17
star_color dd 0

;detalii buton play
button_play_x equ 270
button_play_y equ 270 
button_size equ 50
click_play dd 0 ;nu s-a dat click pe butonul de play

;detalii caramizi
caramida_width equ 85
caramida_height equ 18
	

directieP dd ? ;initial paleta nu se misca
directieM dd 4 ;directia mingii

coliziune dd -1 ;ce loveste mingea
coliziune_paleta dd ?
coliziune_caramida dd 0

format db "%d", 13, 10, 0

caramizi dd 24
tasta dd 0 ;nu s-a apasat nicio tasta dupa ce s-a dat play
white dd 0FFFFFFh

include digits.inc
include letters.inc
include bonus.inc


.code
; procedura make_text afiseaza o litera sau o cifra la coordonatele date
; arg1 - simbolul de afisat (litera sau cifra)
; arg2 - pointer la vectorul de pixeli
; arg3 - pos_x
; arg4 - pos_y

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;procedura pt desenarea bonusului
make_bonus proc
	push ebp
	mov ebp, esp
	pusha
	
	;desenam steaua 
	mov eax, [ebp + arg1] ;citim simbolul de afisat
	sub eax, '*'
	mov star_color, 0E7CD19h
	lea esi, bonus
	
draw_the_star:
	mov ebx, bonus_width
	mul ebx
	mov ebx, bonus_height
	mul ebx
	add esi, eax
	mov ecx, bonus_height
	
bucla_simbol_linii_bonus:
	mov edi, [ebp+arg2] ;pointer la matricea de pixeli
	mov eax, [ebp+arg4] ;pointer la y
	add eax, bonus_height
	sub eax, ecx
	mov ebx, area_width
	mul ebx
	add eax, [ebp+arg3] ;pointer la x
	shl eax, 2
	add edi, eax
	push ecx
	mov ecx, bonus_width
bucla_simbol_coloane_bonus:
	cmp byte ptr [esi], 0
	je simbol_pixel_alb_bonus
	mov edx, star_color
	mov dword ptr [edi], edx
	jmp simbol_pixel_next_bonus
simbol_pixel_alb_bonus:
	mov dword ptr [edi], 0F3EFD0h ;fundalul patratului/matricii in care se afla steluta
simbol_pixel_next_bonus:
	inc esi
	add edi, 4
	loop bucla_simbol_coloane_bonus
	pop ecx
	loop bucla_simbol_linii_bonus
	
	popa
	mov esp, ebp
	pop ebp
	ret
make_bonus endp

make_bonus_macro macro symbol, drawArea, x, y
	push y
	push x
	push drawArea
	push symbol
	call make_bonus
	add esp, 16
endm
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

make_text proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1] ; citim simbolul de afisat
	cmp eax, 'A'
	jl make_digit
	cmp eax, 'Z'
	jg make_digit
	sub eax, 'A'
	lea esi, letters
	jmp draw_text
make_digit:
	cmp eax, '0'
	jl make_space
	cmp eax, '9'
	jg make_space
	sub eax, '0'
	lea esi, digits
	jmp draw_text
make_space:	
	mov eax, 26 ; de la 0 pana la 25 sunt litere, 26 e space
	lea esi, letters
	
draw_text:
	mov ebx, symbol_width
	mul ebx
	mov ebx, symbol_height
	mul ebx
	add esi, eax
	mov ecx, symbol_height
bucla_simbol_linii:
	mov edi, [ebp+arg2] ; pointer la matricea de pixeli
	mov eax, [ebp+arg4] ; pointer la coord y
	add eax, symbol_height
	sub eax, ecx
	mov ebx, area_width
	mul ebx
	add eax, [ebp+arg3] ; pointer la coord x
	shl eax, 2 ; inmultim cu 4, avem un DWORD per pixel
	add edi, eax
	push ecx
	mov ecx, symbol_width
bucla_simbol_coloane:
	cmp byte ptr [esi], 0
	je simbol_pixel_alb
	mov dword ptr [edi], 0230FAAh ;culoare litere
	jmp simbol_pixel_next
simbol_pixel_alb:
	mov dword ptr [edi], 0FFFFFFh
simbol_pixel_next:
	inc esi
	add edi, 4
	loop bucla_simbol_coloane
	pop ecx
	loop bucla_simbol_linii
	
	popa
	mov esp, ebp
	pop ebp
	ret
make_text endp

; un macro ca sa apelam mai usor desenarea simbolului
make_text_macro macro symbol, drawArea, x, y
	push y
	push x
	push drawArea
	push symbol
	call make_text
	add esp, 16
endm


print_macro macro x
	push x
	push offset format
	call printf
	add esp, 8
endm

	


draw_ball macro x, y, size_ball, color  ;deseneaza un patrat, practic
	local bucla, bucla_liniee
	;fac un for in for
	mov eax, y
	mov ecx, size_ball
	
	bucla:
		push eax
		push ecx ;punem val din ecx pe stiva pt a o recupera ulterior
	
		mov ebx, area_width
		mul ebx ;eax = y * area_width
		add eax, x
		shl eax, 2
		add eax, area 
		
		mov ecx, size_ball
		bucla_liniee:
			mov dword ptr[eax], color
			add eax, 4
			loop bucla_liniee
		
		pop ecx ;recuperam valoarea initiala
		
		pop eax
		inc eax ;randul urmator
		loop bucla
		
endm	



draw_dreptunghi macro x, y, lungime, latime, color
	local bucla, bucla_liniee
	;fac un for in for
	mov eax, y
	mov ecx, latime
	
	bucla:
		push eax
		push ecx ;punem val din ecx pe stiva pt a o recupera ulterior
	
		mov ebx, area_width
		mul ebx ;eax = y * area_width
		add eax, x
		shl eax, 2
		add eax, area 
		
		mov ecx, lungime
		bucla_liniee:
			mov dword ptr[eax], color
			add eax, 4
			loop bucla_liniee
		
		pop ecx ;recuperam valoarea initiala
		
		pop eax
		inc eax ;randul urmator
		loop bucla
		
endm


line_horizontal macro x, y, len, color
local bucla_linie
	mov eax, y ;eax = y
	mov ebx, area_width
	mul ebx ;eax = y * area_width
	add eax, x
	shl eax, 2
	add eax, area
	mov ecx, len
	
	bucla_linie:
		mov dword ptr[eax], color
		add eax, 4
		loop bucla_linie
endm

line_vertical macro x, y, len, color
local bucla_linie
	mov eax, y ;eax = y
	mov ebx, area_width
	mul ebx ;eax = y * area_width
	add eax, x
	shl eax, 2
	add eax, area
	mov ecx, len
	
	bucla_linie:
		mov dword ptr[eax], color
		add eax, area_width * 4
		loop bucla_linie
endm


;procedura care afiseaza butonul de play
deseneaza_buton proc ;asta e buna
	push ebp
	mov ebp, esp
	pusha
	
	line_horizontal button_play_x, button_play_y, button_size, 00AB3E00h
	line_horizontal button_play_x, button_play_y + button_size, button_size, 0AB3E00h
	
	line_vertical button_play_x, button_play_y, button_size,0AB3E00h
	line_vertical button_play_x + button_size, button_play_y, button_size, 0AB3E00h

	make_text_macro 'P', area, 275, 285
	make_text_macro 'L', area, 285, 285
	make_text_macro 'A', area, 295, 285
	make_text_macro 'Y', area, 305, 285
	
exit_proc:
	popa
	mov esp, ebp
	pop ebp
	ret
deseneaza_buton endp

;==================================================================

first_init proc ;asta se apeleaza bine
	;scriem un mesaj
	push ebp
	mov ebp, esp
	pusha
	
	make_text_macro 'P', area, 200, 100
	make_text_macro 'R', area, 210, 100
	make_text_macro 'O', area, 220, 100
	make_text_macro 'I', area, 230, 100
	make_text_macro 'E', area, 240, 100
	make_text_macro 'C', area, 250, 100
	make_text_macro 'T', area, 260, 100
	
	make_text_macro 'L', area, 280, 100
	make_text_macro 'A', area, 290, 100
	
	make_text_macro 'A', area, 310, 100
	make_text_macro 'S', area, 320, 100
	make_text_macro 'A', area, 330, 100
	make_text_macro 'M', area, 340, 100
	make_text_macro 'B', area, 350, 100
	make_text_macro 'L', area, 360, 100
	make_text_macro 'A', area, 370, 100
	make_text_macro 'R', area, 380, 100
	make_text_macro 'E', area, 390, 100
	
	make_text_macro 'C', area, 240, 120
	make_text_macro 'I', area, 250, 120
	make_text_macro 'O', area, 260, 120
	make_text_macro 'F', area, 270, 120
	make_text_macro 'U', area, 280, 120
	
	make_text_macro 'D', area, 300, 120
	make_text_macro 'I', area, 310, 120
	make_text_macro 'N', area, 320, 120
	make_text_macro 'U', area, 330, 120
	make_text_macro 'T', area, 340, 120
	make_text_macro 'A', area, 350, 120
	
	make_text_macro 'D', area, 270, 140
	make_text_macro 'X', area, 280, 140
	
	make_text_macro 'B', area, 300, 140
	make_text_macro 'A', area, 310, 140
	make_text_macro 'L', area, 320, 140
	make_text_macro 'L', area, 330, 140
	
	desenare_buton_play:
		call deseneaza_buton
		
	exit_procc:
	popa
	mov esp, ebp
	pop ebp
	ret
first_init endp

;======================================================================================

sterge proc
	push ebp
	mov ebp, esp
	pusha

	make_text_macro ' ', area, 200, 100
	make_text_macro ' ', area, 210, 100
	make_text_macro ' ', area, 220, 100
	make_text_macro ' ', area, 230, 100
	make_text_macro ' ', area, 240, 100
	make_text_macro ' ', area, 250, 100
	make_text_macro ' ', area, 260, 100
	
	make_text_macro ' ', area, 280, 100
	make_text_macro ' ', area, 290, 100
	
	make_text_macro ' ', area, 310, 100
	make_text_macro ' ', area, 320, 100
	make_text_macro ' ', area, 330, 100
	make_text_macro ' ', area, 340, 100
	make_text_macro ' ', area, 350, 100
	make_text_macro ' ', area, 360, 100
	make_text_macro ' ', area, 370, 100
	make_text_macro ' ', area, 380, 100
	make_text_macro ' ', area, 390, 100
	
	make_text_macro ' ', area, 240, 120
	make_text_macro ' ', area, 250, 120
	make_text_macro ' ', area, 260, 120
	make_text_macro ' ', area, 270, 120
	make_text_macro ' ', area, 280, 120
	
	make_text_macro ' ', area, 300, 120
	make_text_macro ' ', area, 310, 120
	make_text_macro ' ', area, 320, 120
	make_text_macro ' ', area, 330, 120
	make_text_macro ' ', area, 340, 120
	make_text_macro ' ', area, 350, 120
	
	make_text_macro ' ', area, 270, 140
	make_text_macro ' ', area, 280, 140
	
	make_text_macro ' ', area, 300, 140
	make_text_macro ' ', area, 310, 140
	make_text_macro ' ', area, 320, 140
	make_text_macro ' ', area, 330, 140
	
	line_horizontal button_play_x, button_play_y, button_size, 0FFFFFFh
	line_horizontal button_play_x, button_play_y + button_size, button_size, 0FFFFFFh
	
	line_vertical button_play_x, button_play_y, button_size,0FFFFFFh
	line_vertical button_play_x + button_size, button_play_y, button_size, 0FFFFFFh

	make_text_macro ' ', area, 275, 285
	make_text_macro ' ', area, 285, 285
	make_text_macro ' ', area, 295, 285
	make_text_macro ' ', area, 305, 285
	
	exit_procccc:
	popa
	mov esp, ebp
	pop ebp
	ret

sterge endp

;=======================================================================================
desenare_chestii proc ;si asta
	push ebp
	mov ebp, esp
	pusha
	;caramizi
	;randul 1
	draw_dreptunghi 30, 30, caramida_width, caramida_height, 0E76319h
	draw_dreptunghi 130, 30, caramida_width, caramida_height, 0E76319h
	draw_dreptunghi 230, 30, caramida_width, caramida_height, 0E76319h
	draw_dreptunghi 330, 30, caramida_width, caramida_height, 0E76319h
	draw_dreptunghi 430, 30, caramida_width, caramida_height, 0E76319h
	draw_dreptunghi 530, 30, caramida_width, caramida_height, 0E76319h
	
	;randul 2
	draw_dreptunghi 30, 65, caramida_width, caramida_height, 0E7197Fh
	draw_dreptunghi 130, 65, caramida_width, caramida_height, 0E7197Fh
	draw_dreptunghi 230, 65, caramida_width, caramida_height, 0E7197Fh
	draw_dreptunghi 330, 65, caramida_width, caramida_height, 0E7197Fh
	draw_dreptunghi 430, 65, caramida_width, caramida_height, 0E7197Fh
	draw_dreptunghi 530, 65, caramida_width, caramida_height, 0E7197Fh
	
	;randul 3
	draw_dreptunghi 30, 100, caramida_width, caramida_height, 07AE719h
	draw_dreptunghi 130, 100, caramida_width, caramida_height, 07AE719h
	draw_dreptunghi 230, 100, caramida_width, caramida_height, 07AE719h
	draw_dreptunghi 330, 100, caramida_width, caramida_height, 07AE719h
	draw_dreptunghi 430, 100, caramida_width, caramida_height, 07AE719h
	draw_dreptunghi 530, 100, caramida_width, caramida_height, 07AE719h
	
	;randul 4
	draw_dreptunghi 30, 135, caramida_width, caramida_height, 00FEFD2h
	draw_dreptunghi 130, 135, caramida_width, caramida_height, 00FEFD2h
	draw_dreptunghi 230, 135, caramida_width, caramida_height, 00FEFD2h
	draw_dreptunghi 330, 135, caramida_width, caramida_height, 00FEFD2h
	draw_dreptunghi 430, 135, caramida_width, caramida_height, 00FEFD2h
	draw_dreptunghi 530, 135, caramida_width, caramida_height, 00FEFD2h
	
afisare_minge:
	draw_ball ball_x, ball_y, ball_size, 0511477h

afisare_paleta:
	draw_dreptunghi p_x, p_y, p_width, p_height, 01A2FB8h
	
	exit_proccc:
	popa
	mov esp, ebp
	pop ebp
	ret
desenare_chestii endp
;==================================================================================

;procedura de mutare a paletei
;0 -> paleta sta pe loc
;1 pt stanga
;2 pt dreapta

mutare_paleta proc
	push ebp
	mov ebp, esp
	pusha
	
	cmp directieP, 0 ;sta pe loc
	je eexit_proccc
	
	cmp directieP, 1 ;stanga
	je stanga
	
	cmp directieP, 2 ;dreapta
	je dreapta
	
	
	stanga:
		draw_dreptunghi p_x, p_y, p_width, p_height, 0FFFFFFh
		sub p_x, 10
		draw_dreptunghi p_x, p_y, p_width, p_height, 01A2FB8h
		jmp eexit_proccc
	
	dreapta:
		draw_dreptunghi p_x, p_y, p_width, p_height, 0FFFFFFh
		add p_x, 10
		draw_dreptunghi p_x, p_y, p_width, p_height, 01A2FB8h
		jmp eexit_proccc

	eexit_proccc:
	popa
	mov esp, ebp
	pop ebp
	ret
mutare_paleta endp

;procedura care verifica daca mingea se loveste de marginile ferestrei(sus, jos, stanga, dreapta) si de paleta
;daca se loveste de peretele din stanga/sus/dreapta sau de paleta, mingea isi va schimba directia cu 45 de grade
;daca se loveste de podea =>game over 
;voi declara o variabila care va indica tipul coliziunii
;coliziune = -1 -nu exista coliziune
;coliziune = 0 -loveste podeaua ->game over
;coliziune = 1 - stanga
;coliziune = 2 - dreapta
;coliziune = 3 - sus
;coliziune = 4 - paleta

test_coliziune_minge proc ;IT WORKS OMG
	push ebp
	mov ebp, esp
	pusha
	
	mov ecx, ball_x
	
	test_stanga:
	cmp ecx, 10 ;x
	je coliziune_stanga
	
	test_dreapta:
	add ecx, ball_size ;x+ball_size
	mov eax, area_width
	sub eax, 10
	cmp ecx, eax ;area_width-10
	je coliziune_dreapta

	mov ecx, ball_y
	
	test_sus:
	cmp ecx, 10
	je coliziune_sus
	
	add ecx, ball_size ;y+ball_size
	mov eax, area_height
	sub eax, 10
	
	test_jos:
	cmp ecx, eax
	je game_over_babe
	
	jmp paleta
	
	coliziune_stanga:
		mov coliziune, 1
		print_macro coliziune
		;sunt 2 tipuri de coliziune la stanga
		;cand mingea vine de jos si cand vine de sus
		mov eax, directieM
		cmp eax, 1 ;mingea vine de jos si loveste peretele din stanga
		je schimba1
		cmp eax, 2 ;mingea vine de sus si loveste peretele din stanga
		je schimba2
		jmp test_dreapta
		schimba1:
			mov directieM, 3
			print_macro directieM
			jmp aheh
			
		schimba2:
			mov directieM, 4
			jmp aheh
			
	coliziune_dreapta:
		mov coliziune, 2
		print_macro coliziune
		mov eax, directieM
		cmp eax, 3
		je schimba3
		cmp eax, 4
		je schimba4
		jmp aheh
		schimba3:
			mov directieM, 1
			jmp aheh
			
		schimba4:
			mov directieM, 2
			jmp aheh
			
	coliziune_sus:
		mov coliziune, 3
		print_macro coliziune
		mov eax, directieM
		cmp eax, 1
		je schimba5
		
		cmp eax, 3
		je schimba6
		jmp aheh
		
		schimba5:
			mov directieM, 2
			jmp aheh
		
		schimba6:
			mov directieM, 4
			jmp aheh
	

	paleta:
		;trebuie verificat daca mingea se afla in intervalul paletei
		mov ecx, ball_y
		add ecx, ball_size ;partea de jos a mingii
		mov eax, p_y
		cmp ecx, eax
		jae continue
		jmp aheh

		continue:
			add eax, p_height
			cmp ecx, eax
			jbe continue1
			jmp aheh
			
		continue1:
			mov eax, p_x
			mov ecx, ball_x
			cmp ecx, eax
			jae continue2
			jmp aheh
		
		continue2:
			add eax, p_width
			cmp ecx, eax
			jbe loveste_paleta
			jmp aheh
			loveste_paleta:
				mov coliziune, 4
				mov eax, directieM
				cmp eax, 4
				je schimba7
				
				cmp eax, 2
				je schimba8
				jmp aheh
				schimba7:
					mov directieM, 3
					draw_dreptunghi p_x, p_y, p_width, p_height, 01A2FB8h ;ca sa nu se stearga parti din paleta
					jmp aheh
				
				schimba8:
					mov directieM, 1
					draw_dreptunghi p_x, p_y, p_width, p_height, 01A2FB8h
					jmp aheh
				
		
	game_over_babe:
		mov directieM, 0
		make_text_macro 'G', area, 270, 260
		make_text_macro 'A', area, 280, 260
		make_text_macro 'M', area, 290, 260
		make_text_macro 'E', area, 300, 260
		make_text_macro ' ', area, 310, 260
		make_text_macro 'O', area, 320, 260
		make_text_macro 'V', area, 330, 260
		make_text_macro 'E', area, 340, 260
		make_text_macro 'R', area, 350, 260
		
aheh:
	popa
	mov esp, ebp
	pop ebp
	ret
test_coliziune_minge endp

	
;==============================================================================

schimba_directia proc
	push ebp
	mov ebp, esp
	pusha
	
	cmp coliziune_caramida, 0
	je ade
	
	mov eax, directieM
	cmp  eax, 1
	je directie1
	
	cmp eax, 2
	je directie2
	
	cmp eax, 3
	je directie3
	
	cmp eax, 4
	je directie4
	
	directie1:
		mov directieM, 2
		jmp ade
		
	directie2:
		mov directieM, 1
		jmp ade
		
	directie3:
		mov directieM, 4
		jmp ade
		
	directie4:
		mov directieM, 3
	jmp ade
	
	ade:
	popa
	mov esp, ebp
	pop ebp
	ret
schimba_directia endp

;declar toate coordonatele caramizilor global?
;testam pt fiecare caramida?
;e coliziune atunci cand coordonatele mingii sunt in interiorul caramizii

macro_coliziune_caramida macro caramida_x, caramida_y, color
local available, syrup, arie1, arie2, sweet, boom, yas, erno, ban, emmanuel, pla
	mov eax, ball_y
	mov ecx, caramida_y
	cmp eax, ecx
	jae arie1
	jmp syrup
	
	arie1:
		add ecx, caramida_height
		cmp eax, ecx
		jbe arie2
		jmp syrup
		
		arie2:
			mov eax, ball_x
			mov ecx, caramida_x
			cmp eax, ecx
			jae boom
			jmp syrup
			boom:
				add ecx, caramida_width
				cmp eax, ecx
				jbe sweet
				jmp syrup
				 sweet:
				 	mov eax, color
					print_macro eax
					cmp eax, 0FFFFFFh
					je yas
					mov coliziune_caramida, 1
					call schimba_directia
					sub caramizi, 1
					draw_dreptunghi caramida_x, caramida_y,caramida_width, caramida_height, 0FFFFFFh
					draw_ball ball_x, ball_y, ball_size, 0511477h
					
	
syrup:
	mov eax, ball_y
	add eax, ball_size
	mov ecx, caramida_y
	cmp eax, ecx
	jae erno
	jmp yas
	
	erno:
		add ecx, caramida_height
		cmp eax, ecx
		jbe ban
		jmp yas
		
		ban:
			mov eax, ball_x
			mov ecx, caramida_x
			cmp eax, ecx
			jae emmanuel
			jmp yas
			
			emmanuel:
				add ecx, caramida_width
				cmp eax, ecx
				jbe pla
				jmp yas
				
				pla:
					mov eax, color
					print_macro eax
					cmp eax, 0FFFFFFh
					je yas
			
					mov coliziune_caramida, 1
					call schimba_directia
					sub caramizi, 1
					draw_dreptunghi caramida_x, caramida_y,caramida_width, caramida_height, 0FFFFFFh
					draw_ball ball_x, ball_y, ball_size, 0511477h
					
			
yas:
mov coliziune, 0
endm

test_caramizi proc
	push ebp
	mov ebp, esp
	pusha

	;randul 1
	macro_coliziune_caramida 30, 30, 0E76319h
	macro_coliziune_caramida 130, 30, 0E76319h
	macro_coliziune_caramida 230, 30, 0E76319h
	macro_coliziune_caramida 330, 30, 0E76319h
	macro_coliziune_caramida 430, 30, 0E76319h
	macro_coliziune_caramida 530, 30, 0E76319h
	
	;randul 2
	macro_coliziune_caramida 30, 65, 0E7197Fh
	macro_coliziune_caramida 130, 65, 0E7197Fh
	macro_coliziune_caramida 230, 65, 0E7197Fh
	macro_coliziune_caramida 330, 65, 0E7197Fh
	macro_coliziune_caramida 430, 65, 0E7197Fh
	macro_coliziune_caramida 530, 65, 0E7197Fh
	
	;randul 3
	macro_coliziune_caramida 30, 100, 07AE719h
	macro_coliziune_caramida 130, 100, 07AE719h
	macro_coliziune_caramida 230, 100, 07AE719h
	macro_coliziune_caramida 330, 100, 07AE719h
	macro_coliziune_caramida 430, 100, 07AE719h
	macro_coliziune_caramida 530, 100, 07AE719h
	
	;randul 4
	macro_coliziune_caramida 30, 135, 00FEFD2h
	macro_coliziune_caramida 130, 135, 00FEFD2h
	macro_coliziune_caramida 230, 135, 00FEFD2h
	macro_coliziune_caramida 330, 135, 00FEFD2h
	macro_coliziune_caramida 430, 135, 00FEFD2h
	macro_coliziune_caramida 530, 135, 00FEFD2h

	popa
	mov esp, ebp
	pop ebp
	ret
test_caramizi endp

;procedura de "mutare" a mingii
;in matricea de pixeli mingea va avea 4 directii, pe diagonala
;0 - sta pe loc
;1 - stanga sus
;2 - stanga jos
;3 - dreapta sus
;4 - dreapta jos
move_ball proc
	push ebp
	mov ebp, esp
	pusha
	
	;print_macro directieM
	cmp directieM, 0 ;sta pe loc
	je doamne
	
	cmp directieM, 1 ;stanga sus
	je stanga_sus
	
	cmp directieM, 2 ;stanga jos
	je stanga_jos
	
	cmp directieM, 3 ;dreapta sus
	je dreapta_sus
	
	cmp directieM, 4 ;dreapta jos
	je dreapta_jos
	
	stanga_sus:
		draw_ball ball_x, ball_y, ball_size, 0FFFFFFh
		sub ball_x, 10
		sub ball_y, 5
		
		;print_macro coliziune
		draw_ball ball_x, ball_y, ball_size, 0511477h
		call test_coliziune_minge
		call test_caramizi
		jmp doamne
		
	stanga_jos:
		draw_ball ball_x, ball_y, ball_size, 0FFFFFFh
		sub ball_x, 10
		add ball_y, 5
		
		draw_ball ball_x, ball_y, ball_size, 0511477h
		call test_coliziune_minge
		call test_caramizi
		jmp doamne
	
	dreapta_sus:
		draw_ball ball_x, ball_y, ball_size, 0FFFFFFh
		add ball_x, 10
		sub ball_y, 5
		
		draw_ball ball_x, ball_y, ball_size, 0511477h
		call test_coliziune_minge
		call test_caramizi
		jmp doamne
		
	dreapta_jos:
		draw_ball ball_x, ball_y, ball_size, 0FFFFFFh
		add ball_x, 10
		add ball_y, 5
		
		draw_ball ball_x, ball_y, ball_size, 0511477h
		call test_coliziune_minge
		call test_caramizi
	doamne:
	popa
	mov esp, ebp
	pop ebp
	ret
move_ball endp

;==================================================================================
;variabila coliziune_paleta memoreaza tipul coliziunii
;coliziune_paleta = 0 ->nu exista coliziune
;coliziune_paleta = 1 -> coliziune la stanga
;coliziune_paleta = 2 ->coliziune la dreapta
test_coliziune_paleta proc
	push ebp
	mov ebp, esp
	pusha
	
	mov coliziune_paleta, 0
	mov ecx, p_x
	
	cmp ecx, 10
	je col_stg
	
	add ecx, p_width
	mov eax, area_width
	sub eax, 10
	
	cmp ecx, eax
	je col_dr
	jmp dead
	
	col_stg:
		mov coliziune_paleta, 1
		jmp dead
	
	col_dr:
		mov coliziune_paleta, 2
	
	dead:
	popa
	mov esp, ebp
	pop ebp
	ret
test_coliziune_paleta endp

;==================================================================================
; functia de desenare - se apeleaza la fiecare click
; sau la fiecare interval de 200ms in care nu s-a dat click
; arg1 - evt (0 - initializare, 1 - click, 2 - s-a scurs intervalul fara click, 3 - s-a apasat o tasta)
; arg2 - x (in cazul apasarii unei taste, x contine codul ascii al tastei care a fost apasata)
; arg3 - y
draw proc
	push ebp
	mov ebp, esp
	pusha
	
	
	mov eax, [ebp+arg1] ;daca s-a dat click
	cmp eax, 1
	je start_the_game ;sari la validare
	
	cmp eax, 2 ;s-a scurs intervalul de timp fara click	
	je evt_timer ; nu s-a efectuat click pe nimic
	
	cmp eax, 3
	je k_evt
	
	;mai jos e codul care intializeaza fereastra cu pixeli colorati
init_fereastra:
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	push 255 ;culoare fundal
	push area
	call memset
	add esp, 12

	call first_init
		
start_the_game:
	mov eax, [ebp+arg2]
	cmp eax, button_play_x
	jl final_draw
	cmp eax, button_play_x + button_size
	jg final_draw
	mov eax, [ebp+arg3] 
	cmp eax, button_play_y
	jl final_draw
	cmp eax, button_play_y + button_size
	jg final_draw 
	;daca click-ul s-a efectuat in interiorul butonului
	jmp evt_click ;incepe jocul, click_play = 1
	
evt_click:
	mov click_play, 1
	;sterge butonul si mesajul
	call sterge
	;deseneaza jocul
	call desenare_chestii
	jmp final_draw

k_evt: ;s-a apasat o tasta, dupa ce s-a dat play
	mov tasta, 1
	mov ebx, click_play ;ca sa nu apara paleta cand apas o tasta inaite sa dau play
	cmp ebx, 0
	je final_draw
	mov eax, [ebp+arg2] ;codul ascii al tastei apasate
	
	cmp eax, 39 ;cod ascii pt dreapta
	je dr
	
	cmp eax, 37 ;cod ascii pt stanga
	je stg
	
	jmp final_draw ;daca nu s-a apasat niciuna din taste
	
	dr:
		print_macro eax
		cmp coliziune_paleta, 2
		je atunci
		jmp altfel
		atunci:
			mov directieP, 0
			jmp continua
		altfel:
			mov directieP, 2
		continua:
		call mutare_paleta
		call test_coliziune_paleta 
		;print_macro coliziune_paleta
		jmp final_draw
	
	stg:
		print_macro eax
		cmp coliziune_paleta, 1
		je executa1
		jmp executa2
		executa1:
			mov directieP, 0
			jmp continuaa
		executa2:
			mov directieP, 1
		continuaa:
			call mutare_paleta
			call test_coliziune_paleta
		
		;print_macro coliziune_paleta
		jmp final_draw
	

afisare_litere:
	;afisam valoarea counter-ului curent (sute, zeci si unitati)
	; mov ebx, 10
	; mov eax, counter
	;cifra unitatilor
	; mov edx, 0
	; div ebx
	; add edx, '0'
	; make_text_macro edx, area, 30, 10
	;cifra zecilor
	; mov edx, 0
	; div ebx
	; add edx, '0'
	; make_text_macro edx, area, 20, 10
	;cifra sutelor
	; mov edx, 0
	; div ebx
	; add edx, '0'
	; make_text_macro edx, area, 10, 10
	
	
	;make_bonus_macro '*', area, 540, 320 
	evt_timer:
		mov ebx, click_play ;ca sa nu apara mingea cand apas o tasta inaite sa dau play
		cmp ebx, 1
		je next
		jmp start_the_game
		next:
			cmp tasta, 1
			je panamea
			jmp start_the_game
			panamea:
				call move_ball
				cmp caramizi, 0
				je win
				jmp final_draw
				win:
					mov directieM, 0
					make_text_macro 'Y', area, 270, 260
					make_text_macro 'O', area, 280, 260
					make_text_macro 'U', area, 290, 260
					make_text_macro ' ', area, 300, 260
					make_text_macro 'W', area, 310, 260
					make_text_macro 'I', area, 320, 260
					make_text_macro 'N', area, 330, 260
				
final_draw:
	popa
	mov esp, ebp
	pop ebp
	ret
draw endp

start:
	;alocam memorie pentru zona de desenat
	
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	call malloc
	add esp, 4
	mov area, eax
	;apelam functia de desenare a ferestrei
	; typedef void (*DrawFunc)(int evt, int x, int y);
	; void __cdecl BeginDrawing(const char *title, int width, int height, unsigned int *area, DrawFunc draw);
	push offset draw
	push area
	push area_height
	push area_width
	push offset window_title
	call BeginDrawing
	add esp, 20
	
	;terminarea programului
	push 0
	call exit
end start