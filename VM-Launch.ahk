SetBatchLines, -1  ; Make the operation run at maximum speed.
SetWorkingDir %A_ScriptDir%
SetBatchLines -1
#NoEnv
#SingleInstance on

;=== Variables
Memsize := 4096
VMtype := "\qemu-system-x86_64w.exe"
USBNo := 0
USBLetter := A
ISODir := "A:\ISO\*.ISO"
ISODirTwo := "A:\AIO\FILES\*.ISO"
IMGDir := "A:\AIO\FILES\*.IMG"
SelectedISO := ""
BootUSB := ""
CoreList := 1
CoresPicked := 2

;=== Get number of cores
EnvGet, ProcessorCount, NUMBER_OF_PROCESSORS
ProcessorCount := Round(ProcessorCount/ 2,0)
ProcessorCount := 6
ci := 2
While (ProcessorCount >= ci)
{
    CoreList := CoreList "|" ci
    ci++
}

;=== Get USB Drive
StringLeft, USBLetter, A_ScriptDir, 1
DNo := ":"
ULetter := USBLetter DNo
Drv := "\\.\" ULetter 

hVol := DllCall( "CreateFile", Str,Drv, UInt,0xC0000000, UInt,0x3, UInt,0, UInt,0x3, UInt,0x0, UInt,0 )
VarSetCapacity( VDE,1024,0 ) 

If DllCall( "DeviceIoControl", UInt,hVol, UInt,0x560000, UInt,0, UInt,0, UInt,&VDE , UInt,1024, UIntP,BR, UInt,0 )
USBNo := NumGet( VDE,8 )
DllCall("CloseHandle", UInt,hVol )

ISODir := ULetter "\ISO\*.ISO"
ISODirTwo := ULetter "\AIO\FILES\*.ISO"
IMGDir := ULetter "\AIO\FILES\*.IMG"


;=== GUI Interface
Gui Main: New, +hWndhMainWnd -MinimizeBox -MaximizeBox
Gui Add, DropDownList, AltSubmit Choose4 vDDLMemory gggLMemory x24 y40 w60, 1GB|2GB|3GB|4GB|6GB|8GB
Gui Add, DropDownList, AltSubmit Choose1 vDDLCPU gggLCPU x100 y40 w120, x64_x86|ARM
Gui Add, DropDownList, AltSubmit Choose2 vCCores gCores x240 y40 w60, %CoreList%
Gui Add, Button, hWndhBtnBootVm vBtnBootVm gggBootVM x24 y320 w120 h23, &Choose Boot Image
Gui Add, Button, hWndhBtnBootVm vBtnBootdisk gggBootdisk x200 y320 w120 h23, &Boot Drive Letter
Gui Add, Text, x24 y16 w120 h23 +0x200, Memory
Gui Add, Text, x100 y16 w120 h23 +0x200, CPU
Gui Add, Text, x240 y16 w120 h23 +0x200, Cores
Gui Add, Text, x24 y64 w300 h23 +0x200, *Boot by double clicking - For testing purposes only.


;=== Get ISOs
Gui Add, ListView, vMyListView gMyListView x24 y88 w360 h212, Name

LV_Add("", "Boot USB Drive") ;Custom Addition

Loop, Files, %ISODir%, R
    LV_Add("", A_LoopFileFullPath)
LV_ModifyCol()  

Loop, Files, %ISODirTwo%, R
    LV_Add("", A_LoopFileFullPath)
LV_ModifyCol()  

Loop, Files, %IMGDir%, R
    LV_Add("", A_LoopFileFullPath)
LV_ModifyCol()  

;=== Show GUI
Gui Show, w400 h368, VM Boot - QEMU
Return

Cores:
Gui, Submit, NoHide
CoresPicked := CCores
Return

;=== Events 
ggLMemory:
Gui, Submit, NoHide
if (DDLMemory = "1")
{
    Memsize = 1G
}
else if (DDLMemory = "2")
{
    Memsize = 2G
}
else if (DDLMemory = "3")
{
    Memsize = 3G
}
else if (DDLMemory = "4")
{
    Memsize = 4G
}
else if (DDLMemory = "5")
{
    Memsize = 6G
}
else if (DDLMemory = "6")
{
    Memsize = 8G
}
Return

ggLCPU:
Gui, Submit, NoHide
if (DDLCPU = "1")
{
    VMType = \qemu-system-x86_64w.exe
}
else if (DDLCPU = "2")
{
    VMType = \qemu-system-armw.exe
}
Return

MyListView:
Gui, Submit, NoHide
if (A_GuiEvent = "DoubleClick")
{
LV_GetText(SelectedISO , A_EventInfo,1)  
StartVM(SelectedISO, CoresPicked, MemSize, Vmtype)
}
Return

ggBootVM:
FileSelectFile, SelectedFile, 3, , Open a file, Image files (*.iso; *.img)
if (SelectedFile = "")
    MsgBox, Boot Image cancelled 
else
    StartVM(SelectedFile, CoresPicked, MemSize, Vmtype,USBNo)
return

ggBootdisk:
FileSelectFolder, folder,, 3, Pick a drive to boot:
if not folder
    return
 
StringLen, size, folder
if (size >3) 
{
        MsgBox, Did not select the root drive 
        return
}
StringLeft, letter, folder, 1
;MsgBox %letter%
BootDrive(letter, CoresPicked, MemSize, Vmtype)
return


menuItm:
Gui, Submit, NoHide
;msgbox % menuChoice
return

MainGuiEscape:
MainGuiClose:
    ExitApp
    
    
;=== Functions 

StartVm(image, cores, memory, VMachine, disk:=0)
{
subfolder := "\Portable"
folder := A_ScriptDir subfolder
ext := ""
StringRight, ext, image , 3 ;File Type
;msgbox %SelectedISO%
;msgbox %folder% 

if (image = "Boot USB Drive")
{
    VMName := " -L . -name USB_DRIVE_Mem_"
    VMStuff := "MB_Cores_" cores " -smp " cores " -m "
    VMFile := " -drive file=\\.\PhysicalDrive"
    VMPara := ",if=ide,index=0,media=disk -net nic -net user "
    BootUSB := folder VMachine VMName memory VMStuff memory VMFile disk VMPara
    Run *RunAs %BootUSB%,,Hide
       return
}

if (ext = "ISO")
{
    SplitPath, image, isoname
	isoname = %isoname% Cores %cores% %memory% MB
    VMName := " -machine pc -name " """" isoname """"
    VMStuff := " -boot d -smp " cores " -m "
    ;VMFile := " -drive format=raw,media=cdrom,readonly,file="
	VMFile := " -cdrom "
    VMPara := " -vga vmware -usbdevice keyboard -monitor stdio -accel hax -accel whpx,kernel-irqchip=off -accel tcg -net nic,model=e1000e -net user -device AC97"
    BootUSB := folder VMachine VMName VMStuff memory VMFile """" . image . """" VMPara 
    ;clipboard := BootUSB
    Run %BootUSB%
       return
}

if (ext = "IMG")
{
    SplitPath, image, isoname
    VMName := " -L . -name IMG-" isoname "_Mem_"
    VMStuff := "MB_Cores_" cores " -smp " cores " -m "
    VMFile := " -hda "
    VMPara := " -net nic -net user "
    BootUSB := folder VMachine VMName memory VMStuff memory VMFile """" . image . """" VMPara
    Run %BootUSB%,,Hide
       return
}
}

BootDrive(dletter, cores, memory, VMachine)
{
subfolder := "\Portable"
folder := A_ScriptDir subfolder
ext := ""

;=== Get Drive Number
DNo := ":"
ULetter := dletter DNo
Drv2 := "\\.\" ULetter

hVol := DllCall( "CreateFile", Str,Drv2, UInt,0xC0000000, UInt,0x3, UInt,0, UInt,0x3, UInt,0x0, UInt,0 )
VarSetCapacity( VDE,1024,0 ) 

If DllCall( "DeviceIoControl", UInt,hVol, UInt,0x560000, UInt,0, UInt,0, UInt,&VDE , UInt,1024, UIntP,BR, UInt,0 )
ddisk := NumGet( VDE,8 )
DllCall("CloseHandle", UInt,hVol )

;=== Boot Physical Disk
    VMName := " -L . -name DRIVE_Mem_"
    VMStuff := "MB_Cores_" cores " -smp " cores " -m "
    VMFile := " -drive file=\\.\PhysicalDrive"
    ;VMPara := ",if=ide,index=0,media=disk -net nic -net user"
    VMPara := ",format=raw,media=disk  -net nic -net user "
    BootD := folder VMachine VMName memory VMStuff memory VMFile ddisk VMPara
    ;msgbox %BootD%
    Run *RunAs %BootD%,,Hide
return

}
