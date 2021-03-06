# lutp
Win64 console utility to scan a folder for LUT files, create a presets sub-folder, and populate the sub-folder with a generated OpenFX XML file for each LUT found.  The XML files can then be copied to the Vegas Video OFX-LUT presets folder for use in the NLE application.

The XML files created with LutP work with Vegas 17, 18, and 19 by copying them to this Documents folder:

"Documents\OFX Presets\com.vegascreativesoftware_lutfilter\Filter"

The utility requires no installation. It can be run by placing the exe in a folder containing LUT files and clicking on it. Or by opening a Command window and navigating to the LUT folder and invoking it from there.

In Win10, the easiest way to run it is to place the exe somewhere in the Windows search path. Then navigate to the folder containing LUT files with the Windows explorer, ctrl-right-click, then choose "Open PowerShell Here" from the context menu. Then execute the utility by typing "LutP" on the PowerShell command line. In Win11, the same can be done selecting "Open in Windows Terminal" instead.  

LutP is written in x86-x64 assembly language to run under Windows64.  No external libraries, languages, or functions are employed other than those built into Windows.  Project was created in Visual Studio 2022 installed for C++ apps with x64 selected as the solution platform and masm (.targets, .props) checked off as the C++ Build Customization under Build Dependencies. The build is intended to produce a 64-bit exe as a solution.

The app was primarily designed as a vehicle for me to learn how to write x64 apps for Windows in assembly language calling Windows functions which only seem to be documented for apps written in C++. Windows functions used in this application can be found at the begining of the asm as a list of extrn PROCs. This app does no error checking. It will simply fail if run on a folder containing no LUT files or on a folder which is write-protected. If run on a folder that already has a preset sub-folder, it will create the XML files there. If the pre-existing preset folder already has presets in it matching presets to be created, they will be overwritten.
