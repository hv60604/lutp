; LUTP  read current directory, create preset subdir, and write Vegas LUT preset xmls for each .cube file
;
;  update1: display version 1.0 on console
;           do not create presets folder if no luts
;           shorten code by looping on loop_point instead of get_next
;           minimize make_preset function shadow space... reduce from 80h to 38h (idkw)

extrn    GetStdHandle: PROC
extrn    SetConsoleMode: PROC
extrn    WriteConsoleA: PROC
extrn    GetCurrentDirectoryA: PROC
extrn    FindFirstFileA: PROC
extrn    FindNextFileA: PROC
extrn    CreateFileA: PROC
extrn    CreateDirectoryA: PROC
extrn    CloseHandle: PROC
extrn    WriteFile: PROC
extrn    ExitProcess: PROC


.data

GENERIC_READ          equ 80000000h
GENERIC_WRITE         equ 40000000h
GENERIC_EXECUTE       equ 20000000h
FILE_ATTRIBUTE_NORMAL equ 128
OPEN_EXISTING         equ 3
FILE_SHARE_WRITE      equ 2
FILE_SHARE_READ       equ 1
ERROR_FILE_NOT_FOUND  equ 2
INVALID_HANDLE_VALUE  equ -1
Console               equ -11
maxBuf                equ 260
maxPath               equ 260

wd_msg  byte 'LutP v1.0',13,10,'Current working directory: '

cdir    byte    '.\*.cube',0
pDir    byte    'presets',0
pType   byte    'xml',0
nl      byte    13,10
cFile   byte    maxBuf dup (?)
dirBuf  byte    maxBuf dup (?)
pName   byte    maxBuf dup (?)
resv    qword   0
cFileL  qword   ?
stdout  qword   ?
nbwr    qword   ?
dLen    qword   ?
hFind   qword   ?
pHand   qword   ?

;  OpenFX xml tags describing LUT... the LUT name and path get inserted between the tag groups... cr and spaces inserted before tags for indenting
xml1 db '<?xml version="1.0" encoding="UTF-8"?>',13,'<OfxPreset plugin="com.vegascreativesoftware:lutfilter" context="Filter" name="'
xml2 db '">',13,'  <OfxPlugin>com.vegascreativesoftware:lutfilter</OfxPlugin>',13,'  <OfxPluginVersion>1 0</OfxPluginVersion>',13,'  <OfxParamTypeString name="LUTName"><OfxParamValue>'
xml3 db '</OfxParamValue></OfxParamTypeString>',13,'  <OfxParamTypeString name="LUTFilename"><OfxParamValue>'
xml4 db '</OfxParamValue></OfxParamTypeString>',13,'  <OfxParamTypeChoice name="Interpolation"><OfxParamValue>0</OfxParamValue></OfxParamTypeChoice>',13,'  <OfxParamTypeDouble name="Gain"><OfxParamValue>1.000000</OfxParamValue></OfxParamTypeDouble>',13,'</OfxPreset>'

FindFileData:       ; data structure filled in by FileOpen upon return 
dwFileAttributes    dword  ?  
ftCreationTime      qword ?
ftLastAccessTime    qword ?
ftLastWriteTime     qword ?
nFileSizeHigh       dword ?
nFileSizeLow        dword ?
dwReserved0         dword ?
dwReserved1         dword ?
cFname  byte        maxPath dup (?)
cAlternateFileName  byte 14 dup(?)
dwFileType          dword ?
dwCreatorType       dword ?
wFinderFlags        word ?



.code

main proc
  sub    rsp, 28h             ; allocate shadow space on the stack  

  mov    rcx, maxBuf          ; directory buffer size
  lea    rdx, dirBuf          ; buffer address
  call   GetCurrentDirectoryA   
  mov    dLen, rax            ; # bytes written to buffer

  mov   rcx, Console          ; get standard output handle
  call   GetStdHandle
  mov   stdout, rax

  mov    rcx, stdout          ; display directory message
  lea    rdx, wd_msg
  mov    r8, lengthof wd_msg
  lea    r9, nbwr
  lea    rax, resv
  mov    qword ptr [rsp+32], rax
  call    WriteConsoleA

  mov    rcx, stdout          ; display directory name
  lea    rdx, dirBuf
  mov    r8, lengthof dirBuf
  lea    r9, nbwr
  lea    rax, resv
  mov    qword ptr [rsp+32], rax
  call   WriteConsoleA


  lea    rcx, cdir            ; get first file name in cdir
  lea    rdx, FindFileData
  call   FindFirstFileA
 mov    hFind, rax
 cmp    rax, INVALID_HANDLE_VALUE 
 je     done                  ; no LUT files found

  ; create preset directory
  ;
  ;    c++ def:
  ;BOOL CreateDirectoryA(
  ;  [in]      LPCSTR                lpPathName,
  ;  [in, opt] LPSECURITY_ATTRIBUTES lpSecurityAttributes
  ;);
  ;
  lea    rcx, pDir
  xor    rdx, rdx
  call   CreateDirectoryA
  
loop_point:

  and    dwFileAttributes, 18 ; leave out directories & hidden files
  jnz    get_next


  
  mov    rcx, stdout          ; display new line
  lea    rdx, nl
  mov    r8, lengthof nl
  lea    r9, nbwr
  lea    rax, resv
  mov    qword ptr [rsp+32], rax
  call   WriteConsoleA

  ; high speed scan for offset of end of string null using the old z80 technique
  ;
  lea    rdi, cFname        ; cFname pointer to rdi
  xor    al, al             ; null to al 
  mov    rcx, -1            ; init rcx for ones complement
  repne  scasb              ; incr rcx till null found - rcx will end up with -(L+2)
  not    rcx                ; ones complement negation = L+1
  dec    rcx                ; subtract 1 = string length
  mov    r8, rcx            ; put len in r8 for WriteConsole
  mov    cFileL, rcx        ; save cfile name len

  mov    rcx, stdout        ; display first file name - r8 already has the length
  lea    rdx, cFname
  lea    r9, nbwr
  lea    rax, resv
  mov    qword ptr [rsp+32], rax
  call   WriteConsoleA

  call   make_preset


get_next:
  mov    rcx, hFind         ; get next file name in cdir
  lea    rdx, FindFileData
  call   FindNextFileA
  cmp    rax,0              ; returns 0 if no more
  je     done

  jmp    loop_point

  done:
  add    rsp, 28h  
  mov    ecx, eax            ; pass along any uExitCode
  call   ExitProcess
  ;
main endp


make_preset proc
    sub    rsp,38h                  ; reserve shadow space on stack
    
    ; copy folder name to pName
    lea  rsi, pDir                  ; source
    lea  rdi, pName                 ; dest
    mov  rcx, lengthof pDir-1
    rep  movsb
    mov  rax, '\'                   ; append a \
    mov  rcx, 1                     ; chr count
    rep  stosb                      ; write the chr in al and bump the di pointer
    

    ;copy fName -.cube +.xml to pName
    lea  rsi, cFname                ; source
;   lea  rdi, pName                 ; dest... already bumped to correct position
    mov  rcx, cFileL                ; len of file name
    sub  rcx, 4                     ; reduce len 4 chars
    rep  movsb                      ; copy fname w/o type
    lea  rsi, pType                 ; point to 'xml' str
    mov  rcx, 4                     ; len+1 incl \0
    rep  movsb                      ; copy type... pName now contains zero terminated xml preset name

    ; create preset file
    ;
    ;   ;  c++ function def w/regs and stack noted
    ;HANDLE CreateFileA(
    ;rcx    [in]      LPCSTR lpFileName,
    ;rdx    [in]      DWORD  dwDesiredAccess,
    ;r8     [in]      DWORD  dwShareMode,
    ;r9     [in, opt] LPSECURITY_ATTRIBUTES lpSecurityAttributes,
    ;rsp+32 [in]      DWORD  dwCreationDisposition,
    ;rsp+40 [in]      DWORD  dwFlagsAndAttributes,
    ;rsp+48 [in, opt] HANDLE hTemplateFile
    ;)
    ;
    lea  rcx, pName                 ; lpFileName
    mov  rdx, GENERIC_WRITE         ; dwDesiredAccess
    xor  r8, r8                     ; dwShareMode = 0
    xor  r9, r9                     ; lpSecurityAttributes = 0
    mov  qword ptr [rsp+32], 2      ; dwCreationDisposition = SHARED-WRITE
    mov  qword ptr [rsp+40], 128    ; dwFlagsAndAttributes = NORMAL
    mov  qword ptr [rsp+48], 0      ; hTemplateFile = 0
    call CreateFileA

    mov  pHand, rax                 ; save preset handle

    ; write xml1 to preset
    ;
    ;        ;  c++ function def w/regs and stack noted
    ;    BOOL WriteFile(
    ;rcx    [in]           HANDLE       hFile,
    ;rdx    [in]           LPCVOID      lpBuffer,
    ;r8     [in]           DWORD        nNumberOfBytesToWrite,
    ;r9     [out, opt]     LPDWORD      lpNumberOfBytesWritten,
    ;rsp+32 [in, out, opt] LPOVERLAPPED lpOverlapped
    ;    );
    ;
    mov  rcx, pHand                 ; hFile
    lea  rdx, xml1                  ; lpBuffer
    mov  r8, lengthof xml1          ; nNumberOfBytesToWrite
    xor  r9,r9                      ; lpNumberOfBytesWritten
    mov  qword ptr [rsp+32], 0      ; lpOverlapped
    call WriteFile


    ; write fname (w/o .cube) to preset 
    mov  rcx, pHand                 ; target file handle
    lea  rdx, cFname                ; pointer to char string to copy to file 
    mov  r8, cFileL                 ; length of the file name
    sub  r8, 5                      ; -5 the length to omit .cube chars
    xor  r9,r9  
    mov  qword ptr [rsp+32], 0
    call WriteFile

    ; write xml2 to preset
    mov  rcx, pHand
    lea  rdx, xml2
    mov  r8, lengthof xml2
    xor  r9,r9
    mov  qword ptr [rsp+32], 0
    call WriteFile


    ; write full fname to preset
    mov  rcx, pHand
    lea  rdx, cFname
    mov  r8, cFileL
    xor  r9, r9
    mov  qword ptr [rsp+32], 0
    call WriteFile


    ; write xml3 to preset
    mov  rcx, pHand
    lea  rdx, xml3
    mov  r8, lengthof xml3
    xor  r9,r9
    mov  qword ptr [rsp+32], 0
    call WriteFile
    
    ; write full path + fname to preset
    lea  rsi, dirBuf                ; source
    lea  rdi, pName                 ; dest
    mov  rcx, dLen
    rep  movsb
    mov  rax, '\'                   ; add \ between path and filename
    mov  rcx, 1
    rep  stosb

    lea  rsi, cFname                ; source
;   lea  rdi, pName                 ; dest    ... let dest keep on rolling
    mov  rcx, cFileL                ; len of file name
    rep  movsb                      ; copy fname w/o type

    mov  rcx, pHand
    lea  rdx, pName
    mov  r8, cFileL                 ; add len of path and filename
    add  r8, dLen
    inc  r8                         ; +1 for the extra \ 
    xor  r9, r9
    mov  qword ptr [rsp+32], 0
    call WriteFile


    ; write xml4 to preset
    mov  rcx, pHand
    lea  rdx, xml4
    mov  r8, lengthof xml4
    xor  r9,r9
    mov  qword ptr [rsp+32], 0
    call WriteFile

    ; close preset
    mov  rcx, pHand
    call CloseHandle

    add  rsp,38h                    ; recover shadow space previously allocated on the stack
    ret
    ;
make_preset endp

End