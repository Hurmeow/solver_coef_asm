.NOLIST
.NOLISTMACRO

.686
.model flat,stdcall
option casemap:none


.data
	a dw 3 ; 48271
	m dw 10001 ; 2147483647
	temp dw 10001 ; переменная для временной записи значения
.code

;СВ - случайная величина
;ЗЦФ - значение целевой функции


random_gen proc public
; основной генератор СВ в диапазоне [0...10000]
	
	push ebp
	mov ebp, esp
	push eax
	push ebx
	push edx
	push ecx
	
	; [ebp + 8] адрес начала массива /dw/ для выходных значений СВ
	; [ebp + 12] кол-во элементов последовательности (ecx) /dd/
	; [ebp + 16] адрес стартового значения Seed /dw/
	; [ebp + 20] значение m /dw/
	
	mov eax, [ebp + 20]
	mov m, ax
	
	mov ebx, [ebp + 16] ; адрес стартовое значение
	mov eax, [ebx] ; записываем стартовое значение и 16-32бит 0, ax не равен 0
	
	
	mul a ; (DX, AX) = AX* <операнд>
	div m ; DX = (DX,AX) mod  <операнд>,   AX  = (DX,AX) div  <операнд>
	
	mov ecx, [ebp + 12] ; записываем для счетчика
	mov ebx, [ebp + 8] ; загружаем в регистр адрес начала массива/dw/
	

	xor eax, eax
gen:
	mov [ebx], dx ; X[0] = dx
	add ebx, 2; адрес ebx указывает на X[1]
	mov ax, dx 
	
	mul a ; [X[i-1]]x[a]     /////// (DX, AX) = AX* <операнд>
	div m ; ([X[i-1]]x[a]) mod m  ////// DX=(DX,AX) mod  <операнд>, AX =(DX,AX) div  <операнд>
	loop gen

; переписываем значение в Seed на последнее сгененированое
; , для следующей генерации СВ
	mov ebx, [ebp + 16]
	mov [ebx], dx ; новое стартовое значение Seed

	pop ecx
	pop edx
	pop ebx
	pop eax
	pop ebp
	ret 4*4
random_gen endp





start_random_gen proc public
;генерируем N-3 случайных значений Pi(x1,x2,x3)
;и записываем их в Population
;защита от переполнения при больших заданных A, выполнена
;путем сдвига до диапазона [0...15] после генерации случайных значений

	push ebp
	mov ebp, esp
	push eax
	push ebx
	push edx
	push ecx
	
	; [ebp + 8] адрес начала массива Population /db/
	; [ebp + 12] кол-во элементов последовательности (ecx)
	; [ebp + 16] стартовое значение /dw/
	
	mov m, 373
	
	mov ecx, [ebp + 12] ; записываем для счетчика
	mov ax, [ebp + 16] ; стартовое значение и 16-32бит 0, ax не равен 0
	
	mul a ;(DX, AX) = AX* <операнд>
	div m ; DX = (DX,AX) mod  <операнд>,   AX  = (DX,AX) div  <операнд>
	
	mov ebx, [ebp + 8] ; загружаем в регистр адрес начала массива Population
	mov ax, dx
	
	
; заполняем Population СВ
start_gen:
	shl dl, 5 ; уменьшаем сдвигом битов значения Population[i] до максимиум 15,
			  ; необходимо для того, чтобы как можно больше начальных решений
			  ; лежало в диапазоне 0 - 255
	shr dl, 5
	mov [ebx], dl
	inc ebx ; указывает на следующее значение Population[i+1] для записи
	;mov ax, dx ; Population[i] = dl
	mul a ; [Population[i-1]]x[a] ;(DX, AX) = AX* <операнд>
	div m ; ([Population[i-1]]x[a]) mod m  ;
	      ; DX = (DX,AX) mod  <операнд>,   AX  = (DX,AX) div  <операнд>
	mov ax, dx
	loop start_gen
	

	pop ecx
	pop edx
	pop ebx
	pop eax
	pop ebp
	ret 3*4
	
start_random_gen endp	
 




calc_Fi_and_accuracy proc public
; Final_result (x1, x2, x3, F) - это решение.
; Процедура выполняет:
; Вычисляет ЗЦФ Fi (записывает в массив Fi эти значения.
; проверяем ЗЦФ Fi на Fi=D, если да то записываем в Final_result
; и переходим к печати результата и завершению программы.
; Вычисляем невязку Fi-D=b или D-Fi=b и записываем в Fi
; для дальнейших расчетов.

	push ebp
	mov ebp, esp
	sub esp, 4 ; locA1 locA2 locA3 locD все db

	push eax
	push ebx
	push edx
	push ecx
	

	; [ebp - 4] для локальных значений A1, A2, A3, D
	; [ebp + 8] адрес начала массива Fi /dw/
	; [ebp + 12] адрес начала массива Population /db/
	; [ebp + 16] адрес начала A1(+1:A2 ; +2:A3 ; +3;D) /db/
	; [ebp + 20] кол-во элементов последовательности /dd/
	; [ebp + 24] адрес для записи переменных ЦФ и ее значения с наименьшей невязкой
								;Final_result(x1, x2, x3, F)  /db/


	locA1 equ byte ptr[ebp - 4] ; locA1 := A1
	locA2 equ byte ptr[ebp - 3] ; locA2 := A2
	locA3 equ byte ptr[ebp - 2]; locA3 := A3
	locD equ byte ptr[ebp - 1] ; locD := D


; чистим масси Fi от предыдущей итерации /clear_Fi/
	mov ecx, [ebp + 20] ; кол-во циклов
	mov ebx, [ebp + 8] ; адрес начала массива Fi /dw/
	xor eax, eax


clear_Fi:
	mov [ebx], ax
	add ebx, 2
	loop clear_Fi

	
; копируем A1, A2, A3, D для лок использования 
	mov ebx, [ebp + 16] ; адрес начала A1
	mov ecx, [ebx] ; перемещаем в есх A1, A2, A3, D
	mov [ebp - 4], ecx ; копируем A1, A2, A3, D для лок использования


; вычисляем значение для i-особи
pre_calc_Fi:
	mov ecx, [ebp + 20] ; записываем для счетчика  /dd/
	mov ebx, [ebp + 12] ; адрес начала массива Population /db/
	mov edx, [ebp + 8] ; адрес начала массива Fi /dw/


; Вычисляем ЗЦФ для i-особи /calc_Fi/.
; последовательно умножаем и складываем Aixi, если на шаге выходит 
; за 255 то переходим по метке /overflow/ и записываем 0.
; Если ЗЦФ лежит в диапазоне, то вычисляем невязку Fi-D=b или D-Fi=b и b записываем в Fi. 
; Сравниваем Fi с D /compare/ если равно - это решение завершаем вычисления в модуле.
; Переходим на следующую особь. Таким образом проходим все особи /массив Population/.


calc_Fi:
	push ebx
	mov al, [ebx] ; Pi(x1)
	mul locA1 ; (ah, al) := X1 x A1
	jc overflow
	mov [edx], ax ; Fi := A1x1
	
	inc ebx
	mov al, [ebx] ; Pi(x2)
	mul locA2 ; (ah, al) := X2 x A2
	jc overflow
	
	add [edx], ax ; Fi := A1x1 + A2x2
	cmp word ptr[edx], 255
	ja overflow
	
	inc ebx
	mov al, [ebx] ; Pi(x3)
	mul locA3 ; (ah, al) := X3 x A3
	jc overflow
	
	add [edx], ax ; Fi := A1x1 + A2x2 + A3x3
	cmp word ptr[edx], 255
	ja overflow
	jmp compare

	
overflow:
	mov ax, 0
	mov [edx], ax
	jmp next_calc_Fi

		
compare: ; сравниваем Fi c D
	mov al, [edx]
	cmp al, locD ; Fi =? D
	je final ; ebx = x3, Al := F

	jb F_bel_D ; Fi < locD=D
	ja F_abo_D ;  ; Fi > locD=D

		
F_bel_D: ; Fi < D
	mov ah, al
	mov al, locD
	sub al, ah ; в AL невязка
	mov [edx], al ; записываем невязку в Fi
	jmp next_calc_Fi ; переходим на следующий цикл

		
F_abo_D: 
	sub al, locD ; в AL невязка
	mov [edx], al ; записываем невязку в Fi
	jmp next_calc_Fi ; переходим на следующий цикл
	
		
next_calc_Fi:
	pop ebx
	add ebx, 3
	add edx, 2
	loop calc_Fi
	

; теперь Fi=[F1-D, F2-D, ... Fn-D, 0]
jmp end_calc_Fi_and_accuracy


; Запись решения уравнения (x1, x2, x3, F).
; Если решение то [ebx] := x3 (ebx - адрес x3 i-особи) а в AL := F
final:
	pop edx ; помещали в стек значение, очистили регистр
	mov ecx, [ebp + 24] ; адрес начала Final_result 
	mov [ecx + 3], al ; Final_result F = Pi(F)

	mov al, [ebx] ; Pi(x3)
	mov [ecx + 2], al ; Final_result x3 = Pi(x3)

	mov al, [ebx - 1] ; Pi(x2)
	mov [ecx + 1], al ; Final_result x2 = Pi(x2)
	
	mov al, [ebx - 2] ; Pi(x1)
	mov [ecx], al ; Final_result x1 = Pi(x1)


end_calc_Fi_and_accuracy:
	pop ecx
	pop edx
	pop ebx
	pop eax
	mov esp, ebp
	pop ebp
	ret 5*4	
calc_Fi_and_accuracy endp





Calc_Fsum_and_probabilities proc public
; Пропорциональный отбор по схеме https://habr.com/ru/post/128704/

; Меньшие значения невязки |Fi-D|, более желанны и должны иметь 
; больший коэффициент выживаемости (т.е. большую длину отрезка). 
; Следовательно большие значения невязки |Fi-D| будут иметь 
; меньший коэффициент выживаемости (т.е. меньшую длину отрезка). 
; Для создания системы вычислим вероятность выбора каждой особи и 
; возьмем сумму обратных значений коэффициентов, и исходя из этого вычислим длины отрезков.


; Процедура вычисляет:
; Сумму значений коэффициентов 1/F1 + 1/F2... 1/Fn = Fsum


; Сумму ЗЦФ в массиве Fi и записывает в локальную переменную Fsum
	push ebp
	mov ebp, esp
	sub esp, 4 ; Fsum /dw/ - для записи суммы обратных значений коэффициентов, 
			   ; и исходя из этого вычислять проценты.
			   ; 1/F1 + 1/F2... 1/Fn = Fsum
	push eax
	push ebx
	push edx
	push ecx
	; [ebp - 4] для локальное значение Fsum
	; [ebp + 8] адрес начала массива Fi
	; [ebp + 12] кол-во элементов последовательности
	
	Fsum equ word ptr[ebp - 4]
	
	mov esi, [ebp + 8] ; адрес начала Fi
	mov ecx, [ebp + 12] ; записываем для счетчика
	
	mov Fsum, 0 ; обнуляем Fsum

; Сумму значений коэффициентов 1/F1 + 1/F2... 1/Fn = Fsum
Sum_Fsum:
	mov bx, [esi] ; перемещаем значение невязки ЦЗФ в Fi
	cmp bx, 0 ; если значение 0, то данная особь не должна учавствовать в отборе (ЗЦФ не лежит в [0...255]
	je sum_next
	; делим 1 * 10000/Fn, где 10000 масштабный коэффициент (генератор СВ генерирует числа [0...10000] 
	xor edx, edx
	mov ax, 10000
	
	div bx
	add Fsum, ax ; 1*10000/F1 + 1*10000/F2... 1*10000/Fn = Fsum


sum_next:
	add esi, 2
	loop Sum_Fsum
	
; в Fsum сумма значений 1*10000/F1 + 1*10000/F2... 1*10000/Fn = Fsum
	
	mov esi, [ebp + 8] ; адрес начала Fi
	mov ecx, [ebp + 12] ; записываем для счетчика

; теперь вычисляем и записываем в Fi веса отрезков(вероятности) 
; как 1*10000/Fn/Fsum

Probabilities:

	mov bx, [esi] ; перемещаем невязку ЗЦФ из массива Fi
	cmp bx, 0  ; если значение 0, то у данная особи отрезок равен 0 (ЗЦФ не лежит в [0...255])
	je prop_next
	
	; делим 1 * 10000/Fn, где 10000 масштабный коэффициент (генератор СВ генерирует числа [0...10000] 	
	xor edx, edx
	mov ax, 10000
	div bx ; AX = div - берем целое от деления 
	
	mov dx, 10000
	mul dx ; увеличиваем Fn для последующего деления на Fsum
              ; c бОльшей точностью/// в (dx,ax) лежит Fn x 10000
	
	div Fsum ; получаем длину отрезка [(1*10000/Fn)*10000/Fsum] в [0...10000]
	
	
prop_next:	
	mov [esi], ax ; записываем в массив Fi целое значение отрезка [(1*10000/Fn)*10000/Fsum]
	add esi, 2
	loop Probabilities


; в Fi веса отрезков (длины отрезков, обозначим только для описания FLi) и их сумма равна примерно 
; 9995, 9997 - это сопаставимо со значениями выдаваемыми генератором
; случайных чисел random_gen@0 (1 -- 10000), поэтому мы можем расположить
; наши отрезки в виде
; FL1=(0, F1]
; FL2=(F1, F1 + F2]
; FL3=(F1 + F2, F1 + F2 + F3]
; FLn=(F1 + F2+...+Fn-1, 9997 = F1 + F2 + F3+....+Fn]  
; теперь вычисляем эти границы и записываем в Fi
	
	mov ebx, [ebp + 8] ; адрес начала Fi
	mov ecx, [ebp + 12] ; записываем для счетчика
	inc ecx ; тк нужно записать + 1 значение
	xor eax, eax ; первое значение 0

Fi_border:
	mov dx, [ebx] ; перемещаем текущее значение 
	mov [ebx], ax
	add ax, dx
	add ebx, 2
	loop Fi_border
	
; на выходе имеем массив с границами длин весов Fi
	
	pop ecx
	pop edx
	pop ebx
	pop eax
	mov esp, ebp
	pop ebp
	ret 2*4

Calc_Fsum_and_probabilities endp

	



formation_population proc public
; Процедура на основе сгенерированного массива СВ и границ отрезков вероятностей
; Fi формирует новую популяция.
; На данном этапе вычисляется смещение выбранной особи в массиве Population
; (от начала массива) и записывается в массив Generate[i]

	push ebp
	mov ebp, esp
	push eax
	push ebx
	push edx
	push ecx

	; [ebp + 8] адрес начала массива Generate /dw/
	; [ebp + 12] адрес начала массива Fi(dw) - границы отрезков 
	; [ebp + 16] кол-во элементов последовательности


	mov ecx, [ebp + 16]
	mov ebx, [ebp + 8] 

;двойной цикл 
; внешний цикл проходит по массиву Generate. Вложенный цикл проходит
; по массиву с границами(вероятностями) отрезков Fi, и ищет принадлежность
; случайной величины Generate к отрезку. При нахождении записывает смещение
; от начала массива Population до x1 популяции Pi 
; которой принадлежит невязка Fi в Generate.

loop_1:
	mov ax, [ebx] ; значение Generate[i] /dw/
	
	push ecx ; сохраняем внешний счетчик цикла
	
	mov ecx, [ebp + 16] ; загружаем счетчик для внутреннего цикла
	mov edx, [ebp + 12] ; адрес начала массива Fi(dw) - границы отрезков 
loop_2: ; сравниваем Generate[i] и Fi[j+1]
	cmp ax, [edx + 2] ; сравниваем Generate[i] с Fi[j+1]
	jbe loop_3 ; если Generate[i] <= Fi[j+1] переходим на проверку нижней границы Fi[j]
	jmp loop_5 ; если Generate[i] > Fi[j+1] переходим к следующему Fi[j]
	
	
loop_3: ; сравниваем Generate[i] и Fi[j]
	cmp ax, [edx] ; сравниваем Generate[i] с Fi[j]
	ja loop_4 ; если Generate[i] > Fi[j] переходим на смещения в массиве Population
	jmp loop_5 ; если Generate[i] < Fi[j+1] переходим к следующему Fi[j]
	
loop_4:
	mov eax, [ebp + 16]
	sub eax, ecx
	mov ecx, eax
	;; умножение сдвигом + ecx (умножение на 3)
	shl eax, 1 ; умножили на 2
	add eax, ecx ; добавили
	;inc eax ; убрать если нужно смещение в Pi
	mov [ebx], ax ; записываем значение смещение в массиве Population[i] в Generate[i]
	jmp next_gi

loop_5:
	add edx, 2 ; переходим к следующему значению Fi[j]
	loop loop_2
	
next_gi:
	add ebx, 2 ; переходим к следующему значению в Generate
	pop ecx ; восстанавливаем внешний счетчик
	loop loop_1
	

	pop ecx
	pop edx
	pop ebx
	pop eax
	pop ebp
	ret 3*4
formation_population endp





selection proc public
; Процедура заполняет временный массив отобранными особями
; Далее формирует равные длины отрезков вероятности этих особей для определения пар,
; тк у все у них равная вероятность попадания в пару.
; Формирует пары особей для скрещивания. И записывает их в массив Population.
	
	push ebp
	mov ebp, esp
	push eax
	push ebx
	push edx
	push ecx


	; [ebp + 8] счетчик циклов
	; [ebp + 12] адрес массива Fi
	; [ebp + 16] адрес массива Generate
	; [ebp + 20] адрес массива Population
	; [ebp + 24] адрес массива P_selection
	; [ebp + 28] стартовое значение для генератора СВ


; заполняем P_selection отобранными особями.
; Смещение от начала массива Population записано в Generate
	mov ecx, [ebp + 8] ; счетчик цикла
	mov ebx, [ebp + 24] ; адрес массива P_selection
	mov edx, [ebp + 16] ; адрес массива Generate


loop_9:
	mov ax, [edx] ; значение смещение в массиве Population
	mov [ebx], al ; запись этого смещения в массив P_selection
	
	add edx, 2
	add ebx, 3
	loop loop_9

; Теперь в массиве P_selection на позиции Pix1 находится значение смещение особи которую
; нужно записать на позицию Pi в массиве Population
	
; Заполняем массив P_selection уже полноценными особями из Population согласно
; заданному смещению (эти смещения мы отобрали в ходе пропорционального отбора и соответствуют отборанным особям из Population)
	mov ecx, [ebp + 8] ; счетчик цикла
	mov ebx, [ebp + 20] ; адрес массива Population
	mov edx, [ebp + 24] ; адрес массива P_selection
	
	
loop_10:
	mov ebx, [ebp + 20] ; адрес начала Population
	xor eax, eax
	mov al, [edx] ; смещение в P_selection для j-ой особи
	add eax, ebx ; добавляем к смещению адрес начала Population(адрес элемента (P0x1))
				 ; теперь eax = адресу первого элемента X1 отобранного элемента Pi в Population (Pix1)
	
	mov bl, [eax] ; записываем Pix1 из Population
	mov [edx], bl ; записываем Pix1 в P_selection x1 j-ой особи 
	
	inc edx ; переходим к P_selection x2 j-ой особи 
	mov bl, [eax + 1] ; записываем Pix2 из Population 
	mov [edx], bl ; записываем Pix2 в P_selection x2 j-ой особи 
	inc edx ; переходим к P_selection x3 j-ой особи 
	mov bl, [eax + 2] ; записываем Pix3 из Population 
	mov [edx], bl ; записываем Pix3 в P_selection x3 j-ой особи 
	inc edx ; переходим к P_selection x1 [j+1] особи  
	loop loop_10
	
; В P_selection находятся все отобранные особи.
; Теперь нам нужно составить пары для скрещевания особей

; Все отобранные особи имеют равные вероятности для скрещивания.
; Разделим отрезок [0...10000] на число особей в популяции(нормируем), и запишем
; границы этих отрезков в Fi(все эти отрезки имеют равную длину)
; Далее для каждой пары будем генерировать СВ и искать на какие отрезки
; они попадают и следовательно какие 2 особи мы будем скрещивать.
	
	mov ecx, [ebp + 8] ; счетчик соответствует числу особей
	xor edx, edx
	;нормируем отрезок
	mov ax, 10000 ; 10000/cx = длина отрезка
	div cx ; в AX целое от деления
	
	mov si, ax
	
	mov ebx, [ebp + 12] ;  адрес массива Fi в котором будут содержаться границы отрезков
	xor ecx, ecx
	
; теперь записываем границы в Fi счетчик cx используем как множитель
; например если 7 особей, то длина отрезка вероятности будет 1428.
; для особи P1 граница на отрезке [0...10000] будет соответствовать
; (0, 1428], для P2 (1428, 2*1428] и тд 

loop_11:
	mov ax, si ; перемещаем длину отрезка в ax
	mul cx ; и умножаем на множитель
	mov [ebx], ax ; в Fi[j] := граница отрезка для Pi особи 
	
	add ebx, 2
	inc ecx
	cmp ecx, dword ptr[ebp + 8]
	jbe loop_11
	
; [ebp + 8] счетчик циклов
; [ebp + 12] адрес массива Fi
; [ebp + 16] адрес массива Generate
; [ebp + 20] адрес массива Population
; [ebp + 24] адрес массива P_selection
; [ebp + 28] стартовое значение для генератора СВ
	
	mov ecx, [ebp + 8] ; счетчик циклов
	mov edx, [ebp + 20] ; адрес массива Population


; Внешний цикл генерирует СВ и на их основе формирует смещения на
; отобранные особи для пары.
; Внутренний цикл сравниваем смещение отобранной первой особи для пары  
; с последующими. Если смещения разные - то записываем пару в Population 

loop_12:

; генерируем массив СВ для определения пар для скрещивания
	push 10001 ; значение m участвующее в формуле для вычисления СВ
	push [ebp + 28] ; стартовое значение для генератора СВ
	push 10 ; кол-во СВ ( с запасом, если СВ будут указывать на одну и ту же особь)
	push [ebp + 16] ; адрес массива Generate

	call random_gen
	

; формируем особи для определения пар на основе границ вероятностей Fi и СВ лежащих в Generate
	push 10 ;  ; счетчик цикла
	push [ebp + 12] ; адрес массива Fi
	push [ebp + 16] ; адрес массива Generate
	
	call formation_population
	
	
	push ecx ; сохраняем счетчик цикла для внешнего цикла
	
	mov ecx, [ebp + 8] ; загружаем счетчик цикла
	mov ebx, [ebp + 16] ; адрес массива Generate
	xor eax, eax
	mov al, byte ptr[ebx] ; тк смещения в 1 байт(смещение на 1 особь пары)

; Внутренний цикл сравниваем смещение отобранной первой особи для пары  
; Generate[0] с последующими. Если смещения разные - то записываем пару в Population 
loop_13:
	add ebx, 2 ; Generate[i + 1]
	mov ah, byte ptr[ebx] ; (смещение на 2 особь пары)

	cmp al, ah ; если смещения не равны, то нам подходит
	je loop_13 ; если равны то переходим к следующему элементу Generate
	cmp ecx, 0 ; если счетчик равен нулю, то значит не нашлось пары и повторяем заного цикл loop_12
	je loop_12
	
	mov ebx, [ebp + 24] ; адрес первого элемента P_selection
	
	xor ecx, ecx
	mov cl, al ; записываем смещение для 1 особи пары в P_selection
	add ebx, ecx ; получаем адрес x1 Pi в P_selection
	
	mov cl, [ebx] ; перемещаем x1 Pi 
	mov [edx], cl ; записываем в Population x1 i-особи
	inc ebx ; получаем адрес x2 Pi в P_selection
	inc edx ; адрес x2 в Population i-особи
	
	mov cl, [ebx] ; перемещаем x2 Pi 
	mov [edx], cl ; записываем x2 в Population для i-особи
	inc ebx ; получаем адрес x3 Pi в P_selection
	inc edx ; адрес x3 в Population i-особи
	
	mov cl, [ebx] ; перемещаем x3 Pi 
	mov [edx], cl ; записываем x3 в Population для i-особи
	inc edx ; адрес x1 в Population [i+1]-особи (это будет 2 особь пары)

; повторяем те же операции для 2ой особи пары
	mov ebx, [ebp + 24] ; адрес первого элемента P_selection
	mov cl, ah ; записываем смещение для 2 особи пары в P_selection
	add ebx, ecx ; получаем адрес x1 Pi в P_selection
	
	mov cl, [ebx] ; записываем смещение для 1 особи пары в P_selection
	mov [edx], cl ; получаем адрес x1 Pi в P_selection
	inc ebx ; получаем адрес x2 Pi в P_selection
	inc edx ; адрес x2 в Population [i+1] - особи
	
	mov cl, [ebx] ; перемещаем x2 Pi 
	mov [edx], cl ; записываем x2 в Population для [i+1] - особи
	inc ebx ; получаем адрес x3 Pi в P_selection
	inc edx ; адрес x3 в Population [i+1] - особи
	
	mov cl, [ebx] ; перемещаем x3 Pi 
	mov [edx], cl ; записываем x3 в Population для [i+1] - особи
	inc edx ; адрес для 1 особи следующей пары в Population (указывает на x1)
	pop ecx ; восстанавливаем счетчик для внешнего цикла
	loop loop_12

; Теперь в Population записаны отобранные пары особей в виде (P0-1, P0-2, P1-1, P1-2,...,Pn-1, Pn-2)
	pop ecx
	pop edx
	pop ebx
	pop eax
	pop ebp
	ret 6*4
selection endp





crossbreeding proc public
; Процедура определяет путем генерации СВ какой xi в j-паре
; будет обмениваться битами.
; Путем генерации СВ определяет кол-во обмениваемых битов и 
; скрещивает особи в паре.
	push ebp
	mov ebp, esp
	sub esp, 4 ; кол-во циклов
	push eax
	push ebx
	push ecx
	push edx
	
	; [ebp + 8] счетчик цикла
	; [ebp + 12] адрес массива Generate
	; [ebp + 16] адрес массива Population с уже отобраными парами для скрещивания
	; [ebp + 20] стартовое значение для генератора СВ
	
	locN equ dword ptr[ebp - 4] ; кол-во циклов = кол-во пар

	mov ecx, [ebp + 8] ; счетчик цикла
	mov edx, [ebp + 12] ; адрес массива Generate
	mov ebx, [ebp + 16]; адрес массива Population с уже отобраными парами для скрещивания


; генерируем СВ для определения какой xi будет скрещиваться
; СВ возвращаются в массив Generate

	shr ecx, 1 ; делим на 2 количество особей = числу пар
			   ; если не четная то последняя особь идет без скрещивания
	push 10001 ; значение m участвующее в формуле для вычисления СВ
	push [ebp + 20] ; стартовое значение для генератора СВ
	push ecx ; кол-во циклов
	push [ebp + 12] ; адрес массива Generate

	call random_gen
	
	mov locN, ecx ; записываем для локального счетчика


; Определяем какой xi будем скрещивать
; если СВ лежит в (0...3333] то x1
; (3333...6666] то x2
; (6666...10000] то x3
	
loop_14: ; 0 < СВ <= 3333
	mov ax, [edx] ; записываем значение элемента в Generate[i]
	cmp ax, 3333
	ja loop_15
	mov word ptr[edx], 0 ; записываем 0 в Generate[i] (это смещение до x1) 
	jmp final_cross
	
loop_15: ; 3333 < СВ <= 6666
	cmp ax, 6666
	ja loop_16
	mov word ptr[edx], 1 ; записываем 1 в Generate[i] (это смещение до x2) 
	jmp final_cross
	
loop_16: ; 6666 < СВ <= 10000
	mov word ptr[edx], 2 ; записываем 2 в Generate[i] (это смещение до x3) 
	
final_cross:
	add edx, 2
	loop loop_14


	mov ebx, [ebp + 16] ; адрес массива Population с уже отобраными парами для скрещивания
	mov ecx, 0 
	
loop_17:
	mov edx, [ebp + 12] ; адрес массива Generate [0]-после 1 обращения служит
						; для записи туда СВ обмениваемых битов. Также записаны какие xi в паре будут
						; меняться 
	mov eax, ecx ; для дальнейшего определения смещения в массиве Generate
	
	
	shl eax, 1 ; шаг 2 для значений смещения в массиве Generate /dw/
	add edx, eax ; адрес на элемент массива соответствующий i-ой паре
	
	xor eax, eax
	mov ax, [edx] ; смещение 
;#### адрес верный ax значение верное	
	add ebx, eax ; тут адрес указывает на xi Pj 

	push eax ; сохраняем регистр eax (шаг смещения от начала массива Generate)	
; верно ebx
; генерируем СВ для кол-ва обмениваемых битов. Всегда записывается в Generate[0]
; это не портит данных имеющихся в Generate, т.к. адрес смещения для 1 пары уже использовано,
; а для остальных пар свои ячейки

	push 10001 ; значение m участвующее в формуле для вычисления СВ
	push [ebp + 20] ; стартовое значение для генератора СВ
	push 1 ; генерируем 1 значение
	push [ebp + 12] ; адрес массива Generate

	call random_gen


	mov ax, word ptr[ebp + 12] ; перемещаем в регистр значение по адресу Generate[0]

	shl ax, 13 ; сокращаем сдвигом СВ до [0..7] это значение и есть кол-во обмениваемых битов
	shr ax, 13
	
	push ecx ; сохраняем регистр
; обмен битами будем производить по схеме
; 1. обнуляем два 16 бит регистра 
; 2. В верхние регистры загружаем значения обмениваемых xi
; 3. Смещаем 16 бит регистры на полученную величину. В нижних регистрах будут обмениваемые биты
; 4. Обмениваем нижние регистры командой xchg
; 5. Смещаем в обратную сторону 16 бит регистры.

	mov cl, al ; перемещаем число обмениваемых битов
	inc cl ; повышаем на 1 для того чтобы при 0 мы могли обменять нулевые биты и при 7 обменять все биты

	xor eax, eax
	xor edx, edx
	
	mov ah, [ebx] ; загружаем xi 1 особи пары
	mov dh, [ebx + 3] ; загружаем xi 2 особи пары
	
	shr ax, cl ; смещаем нужное кол-во битов в AL
	shr dx, cl ; смещаем нужное кол-во битов в DL
	xchg al, dl ; обмениваем биты AL c DL
	shl ax, cl ; возвращаем в AH скрещенное значение xi 1 особи
	shl dx, cl ; возвращаем в DH скрещенное значение xi 2 особи

	mov [ebx], ah ; записываем скрещенное xi 1 особи пары
	mov [ebx + 3], dh ; записываем скрещенное xi 2 особи пары
	
	pop ecx ; восстанавливаем регистр
	pop eax ; восстанавливаем регистр
	
	sub ebx, eax 
	inc ecx ; увеличиваем счетчик
	add ebx, 6 ; переходим к следующей паре особей
	
	cmp ecx, locN
	jb loop_17

; теперь в Population находятся пары со скрещенными xi
	
	pop edx
	pop ecx
	pop ebx
	pop eax
	mov esp, ebp
	pop ebp
	ret 4*4
crossbreeding endp





mutation proc public
; Процедура мутации i-особи в популяции. Вычисляет возможность
; мутации особи. Если особь мутирует вычисляет и мутирует xi. 
	push ebp
	mov ebp, esp
	push eax
	push ebx
	push ecx
	push edx


	; [ebp + 8] счетчик цикла
	; [ebp + 12] адрес массива Generate 
	; [ebp + 16] адрес массива Population со скрещенными особями
	; [ebp + 20] стартовое значение для генератора СВ
	; [ebp + 24] процент мутации
	
	xor eax, eax
	xor ebx, ebx


; генерируем массив СВ для определения мутации i-особи	
	push 10001  ; значение m участвующее в формуле для вычисления СВ
	push [ebp + 20] ; стартовое значение для генератора СВ
	push [ebp + 8] ; счетчик цикла
	push [ebp + 12] ; адрес массива Generate 
	
	call random_gen
	
	
	mov edx, [ebp + 12] ; адрес начала массива Generate
	mov ecx, [ebp + 8]

loop_18:

	mov ax, [edx] ; загружаем значение СВ для сравнения
	cmp ax, word ptr[ebp + 24] ; проверяем лежит ли данное значение на отрезке
	ja defense ; если ax > мутации то переходим и проставляем значение 10
	
;Особь мутирует - генерируем одну СВ для выбора xi
	push 10001 ; значение m участвующее в формуле для вычисления СВ
	push [ebp + 20] ; стартовое значение для генератора СВ
	push 1 ; генерируем 1 СВ
	push edx ; адрес элемента массива Generate[i]
	
	call random_gen
	
	; определяем какой xi будем менять( ebx растет на +3 за цикл,
	; поэтому мы всегда находится по адресу 
	;push ebx ; сохраняем адрес т.к. в дальнейшем будем с ним работать
	mov ax, word ptr[edx] ; СВ лежит в Generate в 1 ячейке, можем использовать
						  ; т.к. для 1 особи мутацию уже определили
	cmp ax, 3333 ; если лежит то это x1(смещение по адресу 0)
	ja loop_19
	mov word ptr[edx], 0
	jmp loop_21
	
loop_19:
	cmp ax, 6666
	ja loop_20
	mov word ptr[edx], 1 ; если лежит то это x2(смещение по адресу 1)
	jmp loop_21
	
loop_20:
	mov word ptr[edx], 2 ; если лежит то это x3(смещение по адресу 2)
	jmp loop_21

defense:
	mov word ptr[edx], 10 ; если не мутирует проставляем значение 10
	
loop_21:
	add edx, 2 ; переходим к следующему элементу в Generate
	loop loop_18

; теперь в массиве Generate записано смещение от x1 для i особи,
; и 10 если мутация не должна происходить

;делаем инверсию i-го бита особи (мутация)

	; [ebp + 8] счетчик цикла
	; [ebp + 12] адрес массива Generate 
	; [ebp + 16] адрес массива Population со скрещенными особями
	; [ebp + 20] стартовое значение для генератора СВ
	; [ebp + 24] процент мутации
	; [ebp + 30] параметр на мутацию только части битов  при 15 -[0...1]
													; при 14 -[0...3]
													; при 13 -[0...7]
	
	
	mov eax, [ebp + 20]
	mov cx, [eax]
	mov temp, cx



	mov edx, [ebp + 12] ; адрес начала массива Generate со смещение от x1 особи
	mov ecx, [ebp + 8] ; записываем для счетчика
	mov ebx, [ebp + 16] ; адрес начала массива Population
	
	
inverse:	
	cmp word ptr[edx], 10 ; если 10 особь не мутирует
	je inverse_next
	xor eax, eax
	mov ax, [edx] ; записываем смещение от x1 i-ой особи в Population
	add eax, ebx ; адрес изменяемого xi в Population
	
	; [ebp + 8] адрес начала массива /db/
	; [ebp + 12] кол-во элементов последовательности (ecx)
	; [ebp + 16] стартовое значение /dw/
	
	
	push 373 ; значение m участвующее в формуле для вычисления СВ
	push [ebp + 20] ; стартовое значение для генератора СВ
	push 1 ; генерируем 1 СВ
	push edx ; адрес i-го элемента массива в Generate
	
	call random_gen
	
	push ecx ; сохраняем значение счетчика цикла
	push ebx ; сохраняем данный адрес в массиве Population

; наша СВ лежит в Generate[i]
	mov ecx, [ebp + 30] ; перемещаем параметр мутации бита [0...1] или [0...3] или [0...7]
	mov bx, [edx] ; перемещаем СВ 
	shl bx, cl ; уменьшаем значение сдвигом до [0..7]
	shr bx, cl ; в CL номер бита который будет мутировать
	
	mov cl, bl
	
	mov bl, 1 ; маска 0000 0001
	shl bl, cl ; 0000 1000 сдвигаем на n-бит 
	mov cl, [eax] ; значение по адресу изменяемого xi в Population
	xor cl, bl ; меняем Nый бит на противоположное значение
	mov [eax], cl ; загружаем мутированый бит по адресу изменяемого xi в Population
	;mov [edx], cx ; 
	
	pop ebx ; выгружаем сохраненые регистры
	pop ecx ; выгружаем сохраненые регистры

inverse_next:
	add ebx, 3 ; переходим к следующей особи в Population
	add edx, 2 ; переходим к следующей СВ в Generate
	loop inverse
	
	
	mov eax, [ebp + 20]
	mov cx, temp
	mov [eax], cx

	
	pop edx
	pop ecx
	pop ebx
	pop eax
	pop ebp
	ret 5*4
mutation endp
end
