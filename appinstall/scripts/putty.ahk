;
; AutoHotKey Test Script for PuTTY
;
; Copyright (C) 2009 Austin English
;
; This library is free software; you can redistribute it and/or
; modify it under the terms of the GNU Lesser General Public
; License as published by the Free Software Foundation; either
; version 2.1 of the License, or (at your option) any later version.
;
; This library is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
; Lesser General Public License for more details.
;
; You should have received a copy of the GNU Lesser General Public
; License along with this library; if not, write to the Free Software
; Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
;

#Include helper_functions
#Include init_test

DOWNLOAD("http://the.earth.li/~sgtatham/putty/latest/x86/putty.exe", "putty.exe", "ae7734e7a54353ab13ecba780ed62344332fbc6f")

; We're going to run putty a few different times, to test certain things. Leaving the bug 13249 test for last, since it causes a crash.
; We could work around that, but it would be ugly and it's not worth the effort.


;
; TEST SECTION
;
TESTNAME("check for a server that will certainly provide no ssh service on Port 22")

Run, putty.exe www.google.com,
; Notice: www.google.com redirects to www.l.google.com!
ERROR_TEST("PuTTY failed to run.", "PuTTY claimed to start up fine.")

Window_wait("www.l.google.com - PuTTY")
ERROR_TEST("PuTTY window never appeared.", "PuTTY window appeared.")

; On Windows, for me, took up to 55 seconds to time out. On Wine, never times out. I don't think the limit is hard coded,
; but appears to be no longer than a minute. Setting to 2.5 minutes to be safe. Wine bug 18449.

WinWait, PuTTY Fatal Error, Network error: Connection timed out, 150
if ErrorLevel
{
    FileAppend, PuTTY never timed out. TODO_FAILED.`n, %OUTPUT%
    FORCE_CLOSE("www.l.google.com - PuTTY")
    Window_wait("PuTTY Exit Confirmation")
    ControlSend, Button1, {Enter}
    ERROR_TEST("Force closing PuTTY failed.", "Force closing PuTTY after no critical error was fine.")
}
else
{
    FileAppend, PuTTY timed out. Bug 18449 TODO_FIXED.`n, %OUTPUT%
}
IfWinExist, PuTTY Fatal Error, Network error: Connection timed out
{
    WinActivate, PuTTY Fatal Error, Network error: Connection timed out
    ControlSend, Static2, {Enter}
    FORCE_CLOSE("PuTTY (inactive)")
    ERROR_TEST("Closing PuTTY (inactive) failed.", "Closing PuTTY (inactive) succeeded.")
}


;
; TEST SECTION
;
TESTNAME("Run putty a second time, this time connecting to a valid SSH server (no valid credentials though)")

Run, putty.exe,
ERROR_TEST("PuTTY failed to run.", "PuTTY claimed to start up fine.")

Window_wait("PuTTY Configuration","Specify the destination you want to connect to")
ERROR_TEST("PuTTY window never appeared.", "PuTTY window appeared.")

; Connect to www.winehq.org
ControlSend, Edit1, www.winehq.org{Enter}, PuTTY Configuration
 
; A new Server is untrusted by PuTTY.
; Check if registry key exists (Server is cached in registry)
RegRead, CachedServer, HKEY_CURRENT_USER, Software\SimonTatham\PuTTY\SshHostKeys, rsa2@22:www.winehq.org
If ErrorLevel
{
    Window_wait("PuTTY Security Alert","The server's host key is not cached in the registry.")

    ; Test for bug 13249
    ControlSend, Button3, {Left}{Enter}, PuTTY Security Alert
    Sleep 200

    IfWinExist, Microsoft Visual C++ Runtime Library
    {
        FileAppend, PuTTY Security Alert didn't exit`, exception occured. TODO_FAILED.`n, %OUTPUT%
        ControlSend, Static2, {Enter}, Microsoft Visual C++ Runtime Library
        ; Test isn't really complete, but it's expected to exit here. So just pretend it's complete.
        FileAppend, TEST COMPLETE.`n, %OUTPUT%
        exit 0
    }
    Else
    {
        FileAppend, PuTTY Security Alert exited properly. Bug 13249 TODO_FIXED.`n, %OUTPUT%
    }
    ERROR_TEST("Closing PuTTY Security Alert gave an error.", "PuTTY claimed to exit.")

    ; Prevent race condition
    Sleep 500
}
Else
{
    FileAppend, PuTTY has www.winehq.org server key cached in registry. Could not check for Security Alert related bugs.`n, %OUTPUT%
}

Window_wait("www.winehq.org - PuTTY","")
ERROR_TEST("PuTTY SSH login had an error.", "PuTTY SSH login appeared fine.")


; Finally close application
; A confirmation dialog appears, which couldn't be closed with FORCE_CLOSE
; (with FORCE_CLOSE a second confirmation dialog appears - is this a PuTTY bug?)
CLOSE("www.winehq.org - PuTTY")

Sleep 200
IfWinExist, PuTTY Exit Confirmation
{
    FileAppend, PuTTY Exit Confirmation asked.`n, %OUTPUT%
    ControlSend, Button1, {ENTER}, PuTTY Exit Confirmation
}

ERROR_TEST("Closing PuTTY gave an error.", "PuTTY claimed to exit.")


Sleep 200
WIN_EXIST_TEST("www.winehq.org - PuTTY")
FileAppend, TEST COMPLETE.`n, %OUTPUT%

exit 0
