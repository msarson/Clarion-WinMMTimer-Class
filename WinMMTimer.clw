!===============================================================
! WinMMTimer.clw - Implementation of high-precision multimedia timer for Clarion
!
! This module implements a high-resolution timer using the Windows Multimedia
! Timer API. It provides millisecond precision timing for Clarion applications.
!===============================================================
          MEMBER()
  INCLUDE('WinMMTimer.inc'),ONCE    ! Include timer class definitions
  INCLUDE('CWSYNCHM.INC'),ONCE      ! Include synchronization primitives

          MAP
            ! Windows Multimedia Timer API functions
            MODULE('WINMM.DLL')
              MMT_timeBeginPeriod(LONG uPeriod),PASCAL,RAW,NAME('timeBeginPeriod'),PROC        ! Set timer resolution
              MMT_timeEndPeriod(LONG uPeriod),PASCAL,RAW,NAME('timeEndPeriod'),PROC          ! Restore timer resolution
              MMT_timeSetEvent(LONG delay, LONG resolution, LONG callback, LONG user, LONG mode),LONG,PASCAL,RAW,NAME('timeSetEvent')  ! Create timer
              MMT_timeKillEvent(LONG timerID),PASCAL,RAW,NAME('timeKillEvent'),PROC          ! Destroy timer
            END
            
            ! Windows User32 API functions
            MODULE('USER32.DLL')
              MMT_OutputDebugString(*CSTRING lpOutputString),PASCAL,RAW,NAME('OutputDebugStringA'),PROC  ! Debug output
              MMT_PostMessage(LONG hWnd, UNSIGNED nMsg, UNSIGNED wParam, LONG lParam),BOOL,PASCAL,PROC,NAME('PostMessageA')  ! Post window message
              MMT_CallWindowProcA(LONG lpPrevWndFunc, LONG hWnd, UNSIGNED uMsg, UNSIGNED wParam, LONG lParam),LONG,PASCAL,RAW,NAME('CallWindowProcA')  ! Call original window proc
            END
            
            ! Windows Common Controls subclassing API functions (safer window subclassing)
            MODULE('COMCTL32.DLL')
              MMT_SetWindowSubclass(LONG hWnd, LONG pfnSubclassProc, UNSIGNED uIdSubclass, LONG dwRefData),BOOL,PASCAL,RAW,NAME('SetWindowSubclass'),PROC  ! Set window subclass
              MMT_RemoveWindowSubclass(LONG hWnd, LONG pfnSubclassProc, UNSIGNED uIdSubclass),BOOL,PASCAL,RAW,NAME('RemoveWindowSubclass'),PROC  ! Remove window subclass
              MMT_DefSubclassProc(LONG hWnd, UNSIGNED uMsg, UNSIGNED wParam, LONG lParam),LONG,PASCAL,RAW,NAME('DefSubclassProc')  ! Default subclass procedure
            END

            ! Internal callback functions
            MMCallback(LONG uTimerID, LONG uMsg, LONG dwUser, LONG dw1, LONG dw2),PASCAL,PROC  ! MM Timer callback
            TimerSubclassProc(LONG hWnd, UNSIGNED uMsg, UNSIGNED wParam, LONG lParam, UNSIGNED uIdSubclass, LONG dwRefData),LONG,PASCAL   ! Subclassed window procedure
          END

! Global registry instance shared by all timer instances
GlobalRegistry    WinMMTimerRegistry

!===============================================================
! Registry implementation
!===============================================================

!---------------------------------------------------------------
! WinMMTimerRegistry.Construct
!
! Initialize the timer registry by creating a critical section for
! thread synchronization and a queue to track subclassed windows
!---------------------------------------------------------------
WinMMTimerRegistry.Construct  PROCEDURE()
  CODE
  SELF.Lock &= NewCriticalSection()  ! Create thread synchronization object
  SELF.MapQ  &= NEW(MapQType)        ! Create queue for tracking subclassed windows

!---------------------------------------------------------------
! WinMMTimerRegistry.Destruct
!
! Clean up registry resources when the application terminates
!---------------------------------------------------------------
WinMMTimerRegistry.Destruct   PROCEDURE()
  CODE
  ! Clean up the critical section
  IF ~SELF.Lock &= NULL
    SELF.Lock.Kill()
  END
  
  ! Free the queue memory
  IF ~SELF.MapQ &= NULL
    FREE(SELF.MapQ)
    DISPOSE(SELF.MapQ)
  END

!---------------------------------------------------------------
! WinMMTimerRegistry.RegisterSubclass
!
! Register a window for subclassing, storing its original window procedure
! and incrementing the reference count if already registered
!
! Parameters:
!   hWnd    - Window handle to subclass
!   oldProc - Original window procedure address
!   thread  - Thread ID that created the timer
!---------------------------------------------------------------
WinMMTimerRegistry.RegisterSubclass   PROCEDURE(LONG hWnd, LONG oldProc, LONG thread)
  CODE
  SELF.Lock.Wait()                      ! Acquire thread lock
  
  ! Try to find existing entry for this window in this thread
  SELF.MapQ.Hwnd     = hWnd
  SELF.MapQ.ThreadID = thread
  GET(SELF.MapQ, +SELF.MapQ.Hwnd, +SELF.MapQ.ThreadID)
  
  IF ERRORCODE()
    ! Window not yet registered - create new entry
    CLEAR(SELF.MapQ)
    SELF.MapQ.Hwnd     = hWnd
    SELF.MapQ.OldProc  = oldProc
    SELF.MapQ.RefCount = 1
    SELF.MapQ.ThreadID = thread
    ADD(SELF.MapQ)
  ELSE
    ! Window already registered - increment reference count
    SELF.MapQ.RefCount += 1
    PUT(SELF.MapQ)
  END
  
  SELF.Lock.Release()                   ! Release thread lock

!---------------------------------------------------------------
! WinMMTimerRegistry.UnregisterSubclass
!
! Unregister a window from subclassing, decrementing the reference count
! and removing the entry if no more references exist
!
! Parameters:
!   hWnd    - Window handle to unregister
!
! Returns:
!   LONG    - Original window procedure address if completely unregistered,
!             or 0 if still referenced by other timers
!---------------------------------------------------------------
WinMMTimerRegistry.UnregisterSubclass PROCEDURE(LONG hWnd)
oldProc                                 LONG
  CODE
  oldProc = 0
  SELF.Lock.Wait()                      ! Acquire thread lock
  
  ! Find the window entry for this thread
  SELF.MapQ.Hwnd     = hWnd
  SELF.MapQ.ThreadID = THREAD()
  GET(SELF.MapQ, +SELF.MapQ.Hwnd, +SELF.MapQ.ThreadID)
  
  IF ~ERRORCODE()
    ! Found the entry - decrement reference count
    SELF.MapQ.RefCount -= 1
    
    IF SELF.MapQ.RefCount <= 0
      ! No more references - return original proc and delete entry
      oldProc = SELF.MapQ.OldProc
      DELETE(SELF.MapQ)
    ELSE
      ! Still referenced by other timers - update entry
      PUT(SELF.MapQ)
    END
  END
  
  SELF.Lock.Release()                   ! Release thread lock
  RETURN oldProc                        ! Return original window proc or 0

!---------------------------------------------------------------
! WinMMTimerRegistry.FindOldProc
!
! Find the original window procedure for a given window handle
!
! Parameters:
!   hWnd    - Window handle to look up
!
! Returns:
!   LONG    - Original window procedure address or 0 if not found
!---------------------------------------------------------------
WinMMTimerRegistry.FindOldProc PROCEDURE(LONG hWnd)
oldProc LONG
csmsg  CSTRING(128)
  CODE
  oldProc = 0
  SELF.Lock.Wait()                      ! Acquire thread lock
  
  ! Find window entry by handle only (not thread-specific)
  SELF.MapQ.Hwnd = hWnd
  GET(SELF.MapQ, +SELF.MapQ.Hwnd)       ! search by hWnd only
  
  IF ~ERRORCODE()
    ! Found the entry - get original window procedure
    oldProc = SELF.MapQ.OldProc
  END
  
  SELF.Lock.Release()                   ! Release thread lock
  RETURN oldProc                        ! Return original window proc or 0


!===============================================================
! Timer implementation
!===============================================================

!---------------------------------------------------------------
! WinMMTimerClass.Construct
!
! Initialize a new timer instance and set system timer resolution
!---------------------------------------------------------------
WinMMTimerClass.Construct PROCEDURE()
  CODE
  MMT_timeBeginPeriod(1)                ! Set 1ms timer resolution
  SELF.Registry &= GlobalRegistry       ! Use global registry instance

!---------------------------------------------------------------
! WinMMTimerClass.Destruct
!
! Clean up timer resources when the timer is destroyed
!---------------------------------------------------------------
WinMMTimerClass.Destruct  PROCEDURE()
oldProc                     LONG
  CODE
  SELF.Stop()                           ! Ensure timer is stopped
  MMT_timeEndPeriod(1)                  ! Restore system timer resolution


!---------------------------------------------------------------
! WinMMTimerClass.Start
!
! Start the timer with specified parameters
!
! Parameters:
!   interval - Timer interval in milliseconds
!   w        - Window to receive notifications
!   code     - Notification code to send
!   param    - Optional user parameter (default 0)
!---------------------------------------------------------------
WinMMTimerClass.Start PROCEDURE(UNSIGNED interval, WINDOW w, UNSIGNED code, LONG param)
result                  BOOL
csMsg                   CSTRING(128)
  CODE
  ! Safety check for registry
  IF SELF.Registry &= NULL
    RETURN
  END

  ! Store timer parameters
  SELF.Hwnd       = w{PROP:Handle}      ! Get window handle
  SELF.NotifyCode = code                ! Store notification code
  SELF.Param      = param               ! Store user parameter
  SELF.Interval   = interval            ! Store timer interval
  
  ! Subclass the window using the safer Windows API
  ! This performs the operation atomically and handles reference counting
  result = MMT_SetWindowSubclass(SELF.Hwnd, ADDRESS(TimerSubclassProc), THREAD(), ADDRESS(SELF))
  
  ! Create the multimedia timer
  ! Parameters: delay, resolution, callback function, user data, TIME_PERIODIC
  SELF.TimerID = MMT_timeSetEvent(interval, 1, ADDRESS(MMCallback), ADDRESS(SELF), 1)
!---------------------------------------------------------------
! WinMMTimerClass.Pause
!
! Temporarily pause the timer without unregistering window subclassing
!---------------------------------------------------------------
WinMMTimerClass.Pause PROCEDURE()
  CODE
  ! Kill the timer if it's active
  IF SELF.TimerID
    MMT_timeKillEvent(SELF.TimerID)     ! Stop the multimedia timer
    SELF.TimerID = 0                    ! Clear timer ID
  END

!---------------------------------------------------------------
! WinMMTimerClass.Resume
!
! Resume a previously paused timer using the same parameters
!---------------------------------------------------------------
WinMMTimerClass.Resume PROCEDURE()
  CODE
  ! Only resume if timer is not active and we have valid parameters
  IF ~SELF.TimerID AND SELF.Interval AND SELF.Hwnd
    ! Recreate the multimedia timer with the same parameters
    SELF.TimerID = MMT_timeSetEvent(SELF.Interval, 1, ADDRESS(MMCallback), ADDRESS(SELF), 1)
  END
WinMMTimerClass.Stop  PROCEDURE()
result                  BOOL
  CODE
  ! Always kill the timer first so no more callbacks arrive
  IF SELF.TimerID
    MMT_timeKillEvent(SELF.TimerID)
    SELF.TimerID = 0
  END

  ! Remove the subclass using the safer Windows API
  IF SELF.Hwnd
    result = MMT_RemoveWindowSubclass(SELF.Hwnd, ADDRESS(TimerSubclassProc), THREAD())
    SELF.Hwnd = 0   ! clear handle so Destruct won't double-unsubclass
  END


!---------------------------------------------------------------
! WinMMTimerClass.HandleMessage
!
! Process a timer notification by sending a NOTIFY event to the window
!---------------------------------------------------------------
WinMMTimerClass.HandleMessage PROCEDURE()
  CODE
  ! Send notification to the application using Clarion's NOTIFY mechanism
  NOTIFY(SELF.NotifyCode, THREAD(), SELF.Param)

!===============================================================
! Static callback + wndproc
!===============================================================

!---------------------------------------------------------------
! MMCallback
!
! Callback function called by Windows multimedia timer
! This function posts a message to the window to handle the timer event
!
! Parameters:
!   uTimerID - Timer ID
!   uMsg     - Message (unused)
!   dwUser   - User data (pointer to timer instance)
!   dw1      - Reserved
!   dw2      - Reserved
!---------------------------------------------------------------
MMCallback    PROCEDURE(LONG uTimerID, LONG uMsg, LONG dwUser, LONG dw1, LONG dw2)
lpSelf          &WinMMTimerClass
  CODE
  ! Convert user data to timer instance pointer
  lpSelf &= (dwUser)
  
  ! Post message to window if timer instance is valid
  IF ~lpSelf &= NULL
    ! Post our custom timer message with the timer instance as lParam
    MMT_PostMessage(lpSelf.Hwnd, WM_TIMERMSG, 0, dwUser)
  END

!---------------------------------------------------------------
! TimerSubclassProc
!
! Subclassed window procedure that handles timer messages
! and passes other messages to the original window procedure
!
! Parameters:
!   hWnd         - Window handle
!   uMsg         - Message ID
!   wParam       - Message parameter
!   lParam       - Message parameter (contains timer instance for WM_TIMERMSG)
!   uIdSubclass  - Subclass ID (thread ID in our case)
!   dwRefData    - Reference data (pointer to timer instance)
!
! Returns:
!   LONG    - Message result
!---------------------------------------------------------------
TimerSubclassProc  PROCEDURE(LONG hWnd, UNSIGNED uMsg, UNSIGNED wParam, LONG lParam, UNSIGNED uIdSubclass, LONG dwRefData)
lpSelf               &WinMMTimerClass
  CODE
  ! Handle our custom timer message
  IF uMsg = WM_TIMERMSG
    ! Convert lParam to timer instance pointer
    lpSelf &= (lParam)
    
    ! Process timer notification if instance is valid
    IF ~lpSelf &= NULL AND lpSelf.Hwnd
      lpSelf.HandleMessage()
    END
    
    RETURN 0  ! Message handled
  END

  ! For all other messages, pass to the default subclass procedure
  ! This automatically handles calling the original window procedure
  RETURN MMT_DefSubclassProc(hWnd, uMsg, wParam, lParam)
