#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

ShiftAppVolume( appName, incr )
{
    if !appName
    {
        WinGet, activePID, ID, A
        WinGet, activeName, ProcessName, ahk_id %activePID%
        appName := activeName        
    }
    
    IMMDeviceEnumerator := ComObjCreate( "{BCDE0395-E52F-467C-8E3D-C4579291692E}", "{A95664D2-9614-4F35-A746-DE8DB63617E6}" )
    DllCall( NumGet( NumGet( IMMDeviceEnumerator+0 ) + 4*A_PtrSize ), "UPtr", IMMDeviceEnumerator, "UInt", 0, "UInt", 1, "UPtrP", IMMDevice, "UInt" )
    ObjRelease(IMMDeviceEnumerator)

    VarSetCapacity( GUID, 16 )
    DllCall( "Ole32.dll\CLSIDFromString", "Str", "{77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F}", "UPtr", &GUID)
    DllCall( NumGet( NumGet( IMMDevice+0 ) + 3*A_PtrSize ), "UPtr", IMMDevice, "UPtr", &GUID, "UInt", 23, "UPtr", 0, "UPtrP", IAudioSessionManager2, "UInt" )

    DllCall( NumGet( NumGet( IAudioSessionManager2+0 ) + 5*A_PtrSize ), "UPtr", IAudioSessionManager2, "UPtrP", IAudioSessionEnumerator, "UInt" )
    ObjRelease( IAudioSessionManager2 )
    
    DllCall( NumGet( NumGet( IAudioSessionEnumerator+0 ) + 3*A_PtrSize ), "UPtr", IAudioSessionEnumerator, "UIntP", SessionCount, "UInt" )
    levels := []
    maxlevel := 0
    targets := []
    t := 0
    ISAVs := []
    Loop % SessionCount
    {
        DllCall( NumGet( NumGet( IAudioSessionEnumerator+0 ) + 4*A_PtrSize ), "UPtr", IAudioSessionEnumerator, "Int", A_Index-1, "UPtrP", IAudioSessionControl, "UInt" )
        IAudioSessionControl2 := ComObjQuery( IAudioSessionControl, "{BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D}" )
        ObjRelease( IAudioSessionControl )
        
        DllCall( NumGet( NumGet( IAudioSessionControl2+0 ) + 14*A_PtrSize ), "UPtr", IAudioSessionControl2, "UIntP", PID, "UInt" )
        
        PHandle := DllCall( "OpenProcess", "uint", 0x0010|0x0400, "Int", false, "UInt", PID )
        if !( ErrorLevel or PHandle = 0 )
        {
            name_size = 1023
            VarSetCapacity( PName, name_size )
            DllCall( "psapi.dll\GetModuleFileNameEx" . ( A_IsUnicode ? "W" : "A" ), "UInt", PHandle, "UInt", 0, "Str", PName, "UInt", name_size )
            DllCall( "CloseHandle", PHandle )
            SplitPath PName, PName
            
            if incr
            {
                t += 1
                
                ISimpleAudioVolume := ComObjQuery(IAudioSessionControl2, "{87CE5498-68D6-44E5-9215-6DA47EF883D8}")
                DllCall( NumGet( NumGet( ISimpleAudioVolume+0 ) + 4*A_PtrSize ), "UPtr", ISimpleAudioVolume, "FloatP", level, "UInt" )  ; Get volume
                
                if ( PName = appName )
                {
                    level += incr
                    targets.push( t )
                    DllCall( NumGet( NumGet( ISimpleAudioVolume+0 ) + 5*A_PtrSize ), "UPtr", ISimpleAudioVolume, "Int", 0, "UPtr", 0, "UInt" )  ; Unmute
                }
                ISAVs.push( ISimpleAudioVolume )
                levels.push( level )
                maxlevel := max( maxlevel, level )
            }
            else
            {
                if ( PName = appName )
                {
                    ISimpleAudioVolume := ComObjQuery(IAudioSessionControl2, "{87CE5498-68D6-44E5-9215-6DA47EF883D8}")
                    DllCall( NumGet( NumGet( ISimpleAudioVolume+0 ) + 6*A_PtrSize ), "UPtr", ISimpleAudioVolume, "IntP", muted )  ; Get mute status
                    maxlevel := maxlevel or muted
                    ISAVs.push( ISimpleAudioVolume )
                }
            }
        }
        ObjRelease(IAudioSessionControl2)
    }
    ObjRelease(IAudioSessionEnumerator)
    
    if incr
    {
        if ( maxlevel = 0.0 ) or ( maxlevel = 1.0 )
        {
            for i, t in targets
                DllCall( NumGet( NumGet( ISAVs[t]+0 ) + 3*A_PtrSize ), "UPtr", ISAVs[t], "Float", levels[t], "UPtr", 0, "UInt" )
        }
        else
        {
            VarSetCapacity( GUID, 16 )
            DllCall( "Ole32.dll\CLSIDFromString", "Str", "{5CDF2C82-841E-4546-9722-0CF74078229A}", "UPtr", &GUID)
            DllCall( NumGet( NumGet( IMMDevice+0 ) + 3*A_PtrSize ), "UPtr", IMMDevice, "UPtr", &GUID, "UInt", 7, "UPtr", 0, "UPtrP", IEndpointVolume, "UInt" )

            DllCall( NumGet( NumGet( IEndpointVolume+0 ) + 9*A_PtrSize ), "UPtr", IEndpointVolume, "FloatP", MasterLevel ) ; Get master level
            DllCall( NumGet( NumGet( IEndpointVolume+0 ) + 7*A_PtrSize ), "UPtr", IEndpointVolume, "Float", MasterLevel * maxlevel, "UPtr", 0, "UInt" ) ; Set master level
            ObjRelease( IEndpointVolume )
            
            for i, ISimpleAudioVolume in ISAVs
                DllCall( NumGet( NumGet( ISimpleAudioVolume+0 ) + 3*A_PtrSize ), "UPtr", ISimpleAudioVolume, "Float", min( 1.0, levels[i] / maxlevel ) , "UPtr", 0, "UInt" )  ; Set volume
        }        
    }
    else
    {
        for i, ISimpleAudioVolume in ISAVs
            DllCall( NumGet( NumGet( ISimpleAudioVolume+0 ) + 5*A_PtrSize ), "UPtr", ISimpleAudioVolume, "Int", !maxlevel, "UPtr", 0, "UInt" )  ; Toggle mute status
    }
    ObjRelease( IMMDevice )
    for i, ISimpleAudioVolume in ISAVs
        ObjRelease(ISimpleAudioVolume)
}

StopChromePlayback() {

DetectHiddenWindows, on
SetTitleMatchMode, 2
ControlGet, controlID, Hwnd,,Chrome_RenderWidgetHostHWND1, Google Chrome
ControlFocus,,ahk_id %controlID%
ControlSend, Chrome_RenderWidgetHostHWND1, {space}, Google Chrome
return

}


F20::ShiftAppVolume( "chrome.exe", 0)
F21::StopChromePlayback()