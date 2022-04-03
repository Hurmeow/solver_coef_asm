include C:\MASM\include\console.inc

COMMENT *
	kuznetsov_11_2
	
Решение Диофантова уравнения с помощью генетических алгоритмов.
1.      Постановка задачи
Решить в целых числах (байтах) Диофантово  уравнение [5]:

A1xX1  + A2xX2 + A3xX3  = D,

где xi , i=1,..,3- неизвестные положительные целые (байты), A3 , i=1,..,3 и D – заданные положительные целые константы (байты).

2.      Указания по построению генетического алгоритма [4]
Размер начальной популяции N задаёт пользователь в диапазоне  4<= N<= 10. 
Начальная популяция формируется случайным образом. 
Каждая особь состоит из трёх байтов (x1, x2, x3).

Критерии останова:

1) превышение заданного пользователем количества итераций M;
2) достижение нулевого значения целевой функции (невязки уравнения).

Вид селекции  :   схема пропорционального отбора [4]
Вид скрещивания  :   одноточечное [4] - решения обмениваются битами в случайным образом выбранном xi.
Мутация   :   изменение случайно выбранного бита в случайно заданном xi;
Вероятность мутации задаётся пользователем.

3.      Требования к программе
Программа должна работать в двух режимах:
тестовый
основной
В тестовом режиме программа выводит на экран популяцию решений, получаемую на каждом шаге работы алгоритма.
В основном режиме выводится только решение, значение функции (невязка уравнения, которая в идеале должна обращаться в ноль) 
и количество сделанных итераций.
Все шаги алгоритма (генерация начальной популяции, селекция, скрещивание, мутация, вычисление целевой функции), 
должны быть реализованы в виде отдельных процедур.
*
;СВ - случайная величина
;ЗЦФ - значение целевой функции
.data
	L equ 10
	A1 db 9 ; 0-255
	A2 db 17; 0-255
	A3 db 2 ; 0-255
	D db 255 ; 0-255
	
	N db 10 ; число особей в популяции
	M db 20 ; вероятность мутации
	
	Iteration dw 10000 ; кол-во итераций

	Seed dw 3001 ; основное значение для старта СВ (меняется вводом)
	Seed2 dw 6001 ; значение для старта СВ. Используется в модулях
				  ; mutation (при  m=373, выдает равномерную плотность значений в [0...7]
	
	
	Population db L dup ( 3 dup (1,0,0,0,1,0,0,0,1)); первые 3 особи защита при больших числах
	                ;P1(1, 0, 0), P2(0, 1, 0), P3(0, 0, 1), P4(x1, x2, x3) и тд
	P_selection db L dup ( 3 dup (1,0,1)) ; массив особей отобранными в ходе пропорционального отбора
	
	
	
	Fi dw L + 1 dup (?) ; массив для ЗЦФ (и далее невязки и границ отрезков вероятности)
	Generate dw L dup (?) ; массив для значений СВ (а так же смещений особей в массивах)
	
	
	Final_result db 4 dup(0,0,0,0) ; x1, x2, x3, F - это решение, стартовые значения для D=0

	
	K db 13 ; значение для генерации СВ в диапазоне:
		   ; при 15 -[0...1]
		   ; при 14 -[0...3]
		   ; при 13 -[0...7] используется в модуле mutation
			
	
.code


Start:
    ClrScr

	extrn start_random_gen@0: near ; генератор случайных чисел начальной популяции
	extrn calc_Fi_and_accuracy@0: near ; вычисляет ЗЦФ и невязку для последующего решения
	extrn random_gen@0: near ; генератор случайных чисел
	extrn Calc_Fsum_and_probabilities@0: near ; вычисляет веротности, веса отрезков, и границы этих отрезков (1... 10001]
	extrn formation_population@0: near ; подбор выбранных особей для скрещивания
	extrn selection@0: near ; отбор пар особей
	extrn crossbreeding@0: near ; скрещивание пар особей в xi и j-тыми битами 
	extrn mutation@0: near ; мутация в xi выбранной особи


;Ввод A1, A2, A3
	mov ebx, offset A1
	mov ecx, 1
INPUT_Ai:
	outstr 'Input A'
	outword cl
	outstr ':  '
	inintln ax
	jc INPUT_Ai ; проверка на не число
	cmp ax, 0
	jl INPUT_Ai
	cmp ax, 255
	jg INPUT_Ai
	mov [ebx], al
	inc ebx
	inc ecx
	cmp ecx, 4
	jne INPUT_Ai


;Ввод D
INPUT_D:
	outstr 'Input D:  '
	inintln ax
	jc INPUT_D ; проверка на не число
	cmp ax, 0
	jl INPUT_D
	cmp ax, 255
	jg INPUT_D
	mov D, al

; проверка D = 0
	cmp D, 0
	je out_result


;Ввод кол-ва особей в популяции
INPUT_N:
	outstr 'Input population N:  '
	inintln ax
	jc INPUT_N ; проверка на не число
	cmp ax, 4
	jl INPUT_N
	cmp ax, 10
	jg INPUT_N
	mov N, al


; процент мутации
INPUT_M:
	outstr 'Input mutant M (0--100):  '
	inintln ax
	jc INPUT_M ; проверка на не число
	cmp ax, 0
	jl INPUT_M
	cmp ax, 100
	jg INPUT_M
	mov M, al


; ввод стартового значения для генератора СВ
INPUT_Seed:
	outstr 'Input start Seed (1 -- 20000):  '
	inintln ax
	jc INPUT_Seed ; проверка на не число
	cmp ax, 0
	jl INPUT_Seed
	cmp ax, 20000
	jg INPUT_Seed	
	mov Seed, ax


; ввод кол-ва итераций	
INPUT_Iter:
	outstr 'Input Iteration (1 -- 65000):  '
	inintln ax
	jc INPUT_Iter ; проверка на не число
	cmp ax, 0
	jb INPUT_Iter
	cmp ax, 65000
	ja INPUT_Iter
	mov Iteration, ax


; ввод параметра для модуля мутации (мутирует бит только в определенном диапазоне)
INPUT_K:
	outstr 'Input K (13, 14, 15):  '
	inintln ax
	jc INPUT_K ; проверка на не число
	cmp ax, 13
	jb INPUT_K
	cmp ax, 15
	ja INPUT_K
	mov K, al

	newline
; печать входных данных
	outwordln A1,3, 'A1 = '
	outwordln A2,3, 'A2 = '
	outwordln A3,3, 'A3 = '
	outwordln D,3, 'D = '
	outwordln N,3, 'N = '
	outwordln Seed,3, 'Seed = '
	outwordln Iteration,3, 'Iteration = '
	
	newline

	outword A1,,'Solve the equation:            '
	outstr '*x1 + '
	outword A2
	outstr '*x2 + '
	outword A3
	outstr '*x3 = '
	outword D
	
	newline
	newline

; генерация стартовой популяции	
; вычисляем кол-во оставшихся случайных особей cl=(N-3)x3
; 3 переменные и N-3 особи	

	xor ecx, ecx
	mov al, N
	sub al, 3
	mov cl, al
	shl cl, 1
	add cl, al
	; ecx уже счетчик	

; генерация стартовой популяции
	
	; первые 3 особи имеют значения (1,0,0), (0,1,0), (0,0,1)
	; поэтому передаем адрес на P4x1
	mov eax, offset Population
	add eax, 9
	
	push Seed ; стартовое значение
	push ecx ; счетчик
	push eax ; записываем в стек адрес начала массива популяции
	
	call start_random_gen@0

	
; цикл итераций на регистре dx
	mov edx, 1
Iter:
	
	; печать массива популяции	
	xor ebx, ebx
	mov cl, 0
	outstr 'Population (iteration = '
	outword dx
	outstr '): '
	newline
OUTL:
	outstr 'P'
	outword cl
	outstr ': '
	;outstr '('
	outword Population[ebx],3
	inc ebx
	outword Population[ebx],3, ', '
	inc ebx
	outwordln Population[ebx],3, ', '
	inc ebx
	;outstrln ')'
	inc cl
	cmp cl, N
	jne OUTL
	
	newline
	
	
	
; вычисляем ЗЦФ в Fi
; проверяем на точное решение Fi=D, если да то записываем в Final_result
; и переходим к печати результата
; вычисляем невязку(Fi-D или D-Fi) и записываем в Fi
	
	xor ecx, ecx
	mov cl, N ; ecx уже счетчик
	
	push offset Final_result ; массив решения уравнения (x1, x2, x3, F)
	push ecx 
	push offset A1 ; адрес значения A1 по нему вычисляем в процедуре A2, A3, D
	push offset Population ; адрес начала массива Population
	push offset Fi ; адрес начала массива для невязки популяции
	
	call calc_Fi_and_accuracy@0

; Если при вычислении ЗЦФ в процедуре
; calc_Fi_and_accuracy@0 есть решение  Fi-D = 0, то оно
; будет находится в Final_result.
; сравниваем ЗЦФ в Final_result и если Fi=D, то это и есть решение
; Выходим из цикла и печатаем результат

	mov al, byte ptr [Final_result + 3] ; ЗЦФ в al
	cmp al, D
	je out_result


; заполняем СВ массив Generate

	xor ecx, ecx
	mov cl, N
	
	push 10001 ; значение m участвующее в формуле для вычитсления СВ
	push offset Seed ; стартовое значение
	push ecx ; счетчик циклов
	push offset Generate ; адрес на массив для записи СВ

	call random_gen@0
	

	xor ecx, ecx
	mov cl, N
	
	push ecx ; счетчик
	push offset Fi ; адрес на 1 элемент Fi. Находится невязка |Fi-D|=0
	
	call Calc_Fsum_and_probabilities@0


; Процедура formation_population@0 на основе сгенерированного массива СВ и 
; границ отрезков вероятностей Fi формирует новую популяция.
; На данном этапе вычисляется смещение выбранной особи в массиве Population
; (от начала массива) и записывается в массив Generate

	xor ecx, ecx
	mov cl, N
		
	push ecx ; счетчик цикла
	push offset Fi ; адрес на массив с границами отрезков вероятностей для каждой особи (весь отрезок (0...10000])
	push offset Generate ; адрес на массив со СВ
	
	call formation_population@0


; Формирует пары особей для скрещивания. 
; И записывает их в массив Population.	
	xor ecx, ecx
	mov cl, N
	
	push offset Seed ; стартовое значение для генератора СВ
	push offset P_selection ; адрес на массив для записи отобранных особей
	push offset Population ;
	push offset Generate ; массив со значениями смещения в Population для отобранных особей
	push offset Fi ; адрес массива Fi - будем формировать
	push ecx
	
	call selection@0


; Процедура crossbreeding@0 определяет путем генерации СВ какой xi в j-паре
; будет обмениваться битами.
; Путем генерации СВ определяет кол-во обмениваемых битов и 
; скрещивает особи в паре.

	
	push offset Seed ; стартовое значение для генератора СВ
	push offset Population ; адрес массива Population с уже отобраными парами для скрещивания
	push offset Generate ; адрес массива Generate
	push ecx ; счетчик цикла
	
	call crossbreeding@0
	
	
; Процедура мутации i-особи в популяции. Вычисляет возможность
; мутации особи. Если особь мутирует вычисляет и мутирует xi. 	
	xor ecx, ecx
	mov cl, N

; масштабируем процент мутации в отрезок (0, 10000]
	xor eax, eax
	mov al, M
	mov bl, 100
	mul bl
	xor ebx, ebx
	mov bl, K
	

	push ebx ; параметр мутации бита (один из первых 2/3/7)
	push eax ; процент мутации (нормированый на (0, 10000])
	push offset Seed2 ; стартовое значение для генератора СВ
	push offset Population ; адрес массива Population со скрещенными особями
	push offset Generate ; адрес массива Generate 
	push ecx ; счетчик цикла
	
	call mutation@0


	cmp dx, Iteration
	je no_result
	inc dx
	jmp Iter

no_result:
	outstrln '#####################         NO RESULT!!!!!!!!!!          #####################'
	jmp grand_final
	
out_result:
	xor ebx, ebx
	
	outstrln '###########################          RESULT          ###########################'
	
	outword A1,,'                           '
	outstr '*'
	outword Final_result[ebx]
	outstr ' + '
	outword A2
	outstr '*'
	outword Final_result[ebx + 1]
	outstr ' + '
	outword A3
	outstr '*'
	outword Final_result[ebx + 2]
	outstr ' = '
	outword D
	
	newline
	newline
	
	outword Final_result[ebx],, '                      x1 = '
	outword Final_result[ebx + 1],, '   x2 = '
	outword Final_result[ebx + 2],, '   x3 = '
	outword Final_result[ebx + 3],, '   F = '
	newline
	outwordln dx,, 'Iterations = '

grand_final:
end Start
