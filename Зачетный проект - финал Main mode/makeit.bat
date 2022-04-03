@echo off

  set Name=main
  set Name1=sub
  set path=..\bin;..\..\bin;
  set include=..\include;..\..\include;
  set lib=..\lib;..\..\lib;

  ml /c /coff /Fl %Name%.asm
  ml /c /coff /Fl %Name1%.asm
  
if errorlevel 1 goto errasm

  Link /subsystem:console %Name%.obj %Name1%.obj 

  if errorlevel 1 goto errlink

  %Name%.exe
  goto TheEnd

:errlink
  echo Link Error !!!!!!!!!!!!!!!!!
  goto TheEnd

:errasm
  echo Assembler Error !!!!!!!!!!!!
  goto TheEnd

:TheEnd

pause
