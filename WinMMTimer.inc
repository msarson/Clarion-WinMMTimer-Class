
!===============================================================
! WinMMTimer - High-precision multimedia timer for Clarion applications
!
! This module provides a high-resolution timer implementation using the Windows
! Multimedia Timer API. It offers more precise timing than standard Clarion timers
! with millisecond resolution.
!
! Thread Safety:
! This implementation is designed to be thread-safe through the use of:
! - Windows Common Controls subclassing APIs for atomic window procedure management
! - Critical sections for synchronizing access to shared data
! - Thread-safe singleton pattern for global registry access
! - Defensive callback handling to prevent race conditions
!===============================================================

!-- Windows message constants
WM_USER      EQUATE(0400h)        ! Base for user-defined messages
WM_TIMERMSG  EQUATE(WM_USER + 500) ! Custom message for timer notifications
WM_DESTROY    EQUATE(2)        ! Sent when a window is being destroyed
WM_NCDESTROY  EQUATE(130h)     ! Sent after the non-client area is being destroyed

!===============================================================
! MapQType - Queue structure to track window subclassing information
! Used by the registry to manage subclassed windows
!===============================================================
MapQType  QUEUE,TYPE
Hwnd        LONG      ! Window handle being subclassed
OldProc     LONG      ! Original window procedure address
RefCount    LONG      ! Reference counter for multiple timers on same window
ThreadID    LONG      ! Thread ID that created the timer
          END

!---------------------------------------------------------------
! WinMMTimerRegistry - Registry class to manage window subclassing
!
! This class maintains a registry of subclassed windows to properly
! handle multiple timers attached to the same window and ensure
! correct cleanup when timers are stopped.
!
! Thread Safety:
! - Uses critical sections to synchronize access to the registry
! - Tracks thread IDs to associate timers with their creating threads
! - Works with Windows Common Controls subclassing APIs
!---------------------------------------------------------------
WinMMTimerRegistry    CLASS,TYPE,MODULE('WinMMTimer.clw'),LINK('WinMMTimer.clw')
MapQ                    &MapQType,PRIVATE              ! Queue to track subclassed windows
Lock                    &ICriticalSection,PRIVATE      ! Thread synchronization object
Construct               PROCEDURE()                    ! Initialize registry
Destruct                PROCEDURE()                    ! Clean up registry
RegisterSubclass        PROCEDURE(LONG hWnd, LONG oldProc, LONG thread) ! Register a subclassed window
UnregisterSubclass      PROCEDURE(LONG hWnd),LONG     ! Unregister a subclassed window, returns original proc
                      END


!---------------------------------------------------------------
! WinMMTimerClass - High-precision timer class
!
! This class provides a high-resolution timer implementation using
! the Windows Multimedia Timer API. It offers millisecond precision
! and can be used to generate regular notifications to a window.
!
! Thread Safety:
! - Uses critical sections to protect access to class members
! - Validates window handles before use to prevent race conditions
! - Uses Windows Common Controls subclassing APIs for atomic window procedure management
! - Implements defensive callback handling to prevent race conditions
!---------------------------------------------------------------
WinMMTimerClass   CLASS,TYPE,MODULE('WinMMTimer.clw'),LINK('WinMMTimer.clw')
TimerID             LONG                              ! Windows MM timer ID
Hwnd                LONG                              ! Target window handle
NotifyCode          UNSIGNED                          ! Notification code to send
Param               LONG                              ! User-defined parameter
Interval            UNSIGNED                          ! Requested timer interval in milliseconds
Registry            &WinMMTimerRegistry,PRIVATE       ! Reference to timer registry
Lock                &ICriticalSection,PRIVATE         ! Thread synchronization object for class members

Construct           PROCEDURE()                       ! Initialize timer
Destruct            PROCEDURE()                       ! Clean up timer
Start               PROCEDURE(UNSIGNED interval, WINDOW w, UNSIGNED code, LONG param=0) ! Start the timer
Pause               PROCEDURE()                       ! Temporarily pause the timer
Resume              PROCEDURE()                       ! Resume a paused timer
Stop                PROCEDURE()                       ! Stop the timer completely
HandleMessage       PROCEDURE(),VIRTUAL               ! Process timer notification - can be overridden in derived classes

OnTick              PROCEDURE(),VIRTUAL,SIGNED         ! Virtual method called on each tick, return LEVEL:Benign to stop timer
                  END
