; LUTP  read current directory, create preset subdir, and write Vegas LUT preset xmls for each .cube file

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

Console               equ -11
maxBuf                equ    260
maxPath               equ 260
GENERIC_READ          equ 80000000h
GENERIC_WRITE         equ 40000000h
GENERIC_EXECUTE       equ 20000000h
FILE_ATTRIBUTE_NORMAL equ 128
OPEN_EXISTING         equ 3
FILE_SHARE_WRITE      equ 2
FILE_SHARE_READ       equ 1
ERROR_FILE_NOT_FOUND  equ 2
INVALID_HANDLE_VALUE  equ -1

wd_msg    byte 'Current working directory: '

cdir    byte '.\*.cube',0
pDir    byte 'presets',0
pType   db 'xml',0
nl      byte 13,10
cFile   byte maxBuf dup (?)
dirBuf  byte maxBuf dup (?)
pName   byte maxBuf dup (?)
resv    qword    0
cFileL  qword    ?
stdout  qword    ?
nbwr    qword    ?
dLen    qword    ?
hFind   qword    ?
pHand   qword    ?

;  OpenFX xml tags describing LUT... the LUT name and path get inserted between the tag groups... return chars and spaces inserted before tag to pretty-up the layout 
xml1    db    '<?xml version="1.0" encoding="UTF-8"?>',13,'<OfxPreset plugin="com.vegascreativesoftware:lutfilter" context="Filter" name="'
xml2    db    '">',13,'  <OfxPlugin>com.vegascreativesoftware:lutfilter</OfxPlugin>',13,'  <OfxPluginVersion>1 0</OfxPluginVersion>',13,'  <OfxParamTypeString name="LUTName"><OfxParamValue>'
xml3    db    '</OfxParamValue></OfxParamTypeString>',13,'  <OfxParamTypeString name="LUTFilename"><OfxParamValue>'
xml4    db    '</OfxParamValue></OfxParamTypeString>',13,'  <OfxParamTypeChoice name="Interpolation"><OfxParamValue>0</OfxParamValue></OfxParamTypeChoice>',13,'  <OfxParamTypeDouble name="Gain"><OfxParamValue>1.000000</OfxParamValue></OfxParamTypeDouble>',13,'</OfxPreset>'

FindFileData:        ; data structure filled in by FileOpen upon return 
dwFileAttributes   dword  ?  
ftCreationTime     qword ?
ftLastAccessTime   qword ?
ftLastWriteTime    qword ?
nFileSizeHigh      dword ?
nFileSizeLow       dword ?
dwReserved0        dword ?
dwReserved1        dword ?
cFname             byte    maxPath dup (?)
cAlternateFileName byte 14 dup(?)
dwFileType         dword ?
dwCreatorType      dword ?
wFinderFlags       word ?



.code

main proc
   sub    rsp, 28h        ; allocate shadow space on the stack which Windows might use as a scratch pad  

  mov    rcx, maxBuf        ; directory buffer size
  lea    rdx, dirBuf        ; buffer address
  call    GetCurrentDirectoryA    
  mov    dLen, rax        ; # bytes written to buffer

  mov    rcx, Console        ; get standard output handle
  call    GetStdHandle
  mov    stdout, rax

  mov    rcx, stdout        ; display directory message
  lea    rdx, wd_msg
  mov    r8, lengthof wd_msg
  lea    r9, nbwr
  lea    rax, resv
  mov    qword ptr [rsp+32], rax
  call    WriteConsoleA

  mov rcx, stdout        ; display directory name
  lea rdx, dirBuf
  mov r8, lengthof dirBuf
  lea r9, nbwr
  lea    rax, resv
  mov    qword ptr [rsp+32], rax
  call WriteConsoleA

  ; create preset directory
  ;
;BOOL CreateDirectoryA(
;  [in]           LPCSTR                lpPathName,
;  [in, optional] LPSECURITY_ATTRIBUTES lpSecurityAttributes
;)
;
  lea    rcx, pDir
  xor    rdx, rdx
  call    CreateDirectoryA

  lea    rcx, cdir            ; get first file name in cdir
  lea    rdx, FindFileData
  call    FindFirstFileA
  mov    hFind, rax

  and    dwFileAttributes, 18    ; leave out directories & hidden files
  jnz    get_next


  
  mov rcx, stdout        ; display new line
  lea rdx, nl
  mov r8, lengthof nl
  lea r9, nbwr
  lea    rax, resv
  mov    qword ptr [rsp+32], rax
  call WriteConsoleA

                         ; string scan for null char
  lea    rdi, cFname        ; cFname pointer to rdi
  xor    al, al            ; null to al 
  mov    rcx, -1            ; init for ones complement
  repne    scasb            ; incr cx till null found
  not    rcx                ; ones complement negation
  dec    rcx                ; twos complement - 2 = string length
  mov    r8, rcx            ; put len in r8 for WriteConsole
  mov    cFileL, rcx        ; save cfile name len

  mov rcx, stdout        ; display first file name - assume r8 already has the length
  lea rdx, cFname
  lea r9, nbwr
  lea    rax, resv
  mov    qword ptr [rsp+32], rax
  call WriteConsoleA

  call make_preset


get_next:
  mov    rcx, hFind        ; get next file name in cdir
  lea    rdx, FindFileData
  call    FindNextFileA
  cmp    rax,0            ; returns 0 if no more
  je    done

  and    dwFileAttributes, 18    ; leave out directories & hidden files
  jnz    get_next

  mov rcx, stdout        ; display new line
  lea rdx, nl
  mov r8, lengthof nl
  lea r9, nbwr
  lea    rax, resv
  mov    qword ptr [rsp+32], rax
  call WriteConsoleA

                        ; string scan for null char
  lea    rdi, cFname        ; cFname pointer to rdi
  xor    al, al            ; null to al 
  mov    rcx, -1            ; init for ones complement
  repne    scasb            ; incr cx till null found
  not    rcx                ; ones complement negation
  dec    rcx                ; twos complement - 2 = string length
  mov    r8, rcx            ; put len in r8 for WriteConsole
  mov    cFileL, rcx        ; save cfile name len

  mov rcx, stdout        ; display next file name - assume r8 already has the length
  lea rdx, cFname
  lea r9, nbwr
  lea    rax, resv
  mov    qword ptr [rsp+32], rax
  call WriteConsoleA

  call make_preset
 
 
 jmp    get_next

  done:
  add rsp, 28h  
  mov ecx, eax     ; uExitCode = MessageBox(...)
  call ExitProcess
main endp


make_preset proc
    sub    rsp,80h        ; reserve shadow space on stack
    
    ; copy folder name to pName
    lea    rsi, pDir    ; source
    lea    rdi, pName    ; dest
    mov rcx, lengthof pDir-1
    rep movsb
    mov    rax, '\'
    mov    rcx, 1
    rep stosb
    

    ;copy fName -.cube +.xml to pName
    lea    rsi, cFname    ; source
;    lea    rdi, pName    ; dest
    mov    rcx, cFileL    ; len of file name
    sub rcx, 4        ; reduce len 4 chars
    rep    movsb        ; copy fname w/o type
    lea rsi, pType    ; point to 'xml' str
    mov    rcx, 4        ; len+1 incl \0
    rep movsb        ; copy type... pName now contains zero terminated xml preset name

    ; create preset file
    ;
    ;HANDLE CreateFileA(
    ;rcx    [in]           LPCSTR                lpFileName,
    ;rdx    [in]           DWORD                 dwDesiredAccess,
    ;r8        [in]           DWORD                 dwShareMode,
    ;r9        [in, optional] LPSECURITY_ATTRIBUTES lpSecurityAttributes,
    ;rsp+32    [in]           DWORD                 dwCreationDisposition,
    ;rsp+40    [in]           DWORD                 dwFlagsAndAttributes,
    ;rsp+48    [in, optional] HANDLE                hTemplateFile
    ;)
    ;
    lea    rcx, pName
    mov    rdx, GENERIC_WRITE
    xor    r8, r8
    xor    r9, r9

    mov    qword ptr [rsp+32], 2            ; disposition SHARED-WRITE
    mov    qword ptr [rsp+40], 128            ; attributes NORMAL
    mov    qword ptr [rsp+48], 0

     call    CreateFileA
    mov        pHand, rax            ; save preset handle



    ; write xml1 to preset
;    BOOL WriteFile(
;      [in]                HANDLE       hFile,
;      [in]                LPCVOID      lpBuffer,
;      [in]                DWORD        nNumberOfBytesToWrite,
;      [out, optional]     LPDWORD      lpNumberOfBytesWritten,
;      [in, out, optional] LPOVERLAPPED lpOverlapped
;    );
    mov    rcx, pHand
    lea    rdx, xml1
    mov    r8, lengthof xml1
    xor    r9,r9
    mov qword ptr [rsp+32], 0
    call    WriteFile


    ; write fname (w/o .cube) to preset 
    mov    rcx, pHand
    lea    rdx, cFname
    mov    r8, cFileL
    sub    r8, 5            ; -5 to omit .cube
    xor    r9,r9
    mov qword ptr [rsp+32], 0
    call    WriteFile

    ; write xml2 to preset
    mov    rcx, pHand
    lea    rdx, xml2
    mov    r8, lengthof xml2
    xor    r9,r9
    mov qword ptr [rsp+32], 0
    call    WriteFile


    ; write full fname to preset
    mov    rcx, pHand
    lea    rdx, cFname
    mov    r8, cFileL
    xor    r9, r9
    mov qword ptr [rsp+32], 0
    call    WriteFile


    ; write xml3 to preset
    mov    rcx, pHand
    lea    rdx, xml3
    mov    r8, lengthof xml3
    xor    r9,r9
    mov qword ptr [rsp+32], 0
    call    WriteFile
    
    ; write full path + fname to preset
    lea    rsi, dirBuf    ; source
    lea    rdi, pName    ; dest
    mov rcx, dLen
    rep movsb
    mov    rax, '\'            ; add \ between path and filename
    mov    rcx, 1
    rep stosb

    lea    rsi, cFname    ; source
;    lea    rdi, pName    ; dest    ... let dest keep on rolling
    mov    rcx, cFileL    ; len of file name
    rep    movsb        ; copy fname w/o type

    mov    rcx, pHand
    lea    rdx, pName
    mov    r8, cFileL        ; add len of path and filename
    add r8, dLen
    inc    r8            ; +1 for the extra \ 
    xor    r9, r9
    mov qword ptr [rsp+32], 0
    call    WriteFile


    ; write xml4 to preset
    mov    rcx, pHand
    lea    rdx, xml4
    mov    r8, lengthof xml4
    xor    r9,r9
    mov qword ptr [rsp+32], 0
    call    WriteFile

    ; close preset
    mov        rcx, pHand
    call    CloseHandle

    add        rsp,80h        ; recover shadow space previously allocated on the stack
    ret
make_preset endp

End