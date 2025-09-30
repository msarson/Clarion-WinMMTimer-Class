!===============================================================
! TimerTest.clw - Example application demonstrating WinMMTimer usage
!
! This example shows how to use the WinMMTimer class to create
! high-precision timers in a Clarion application.
!===============================================================
          PROGRAM

          MAP
            TimerWindow()  ! Procedure that demonstrates timer functionality
          END


  INCLUDE('WinMMTimer.inc'),ONCE  ! Include the timer class definitions

! Main application window
AppFrame  APPLICATION('Timer Demo'),AT(,,505,318),CENTER,MASK,SYSTEM,MAX, |
            ICON('WAFRAME.ICO'),STATUS(-1,80,120,45),FONT('Segoe UI',9),RESIZE
            MENUBAR,USE(?Menubar)
              MENU('&File'),USE(?FileMenu)
                ITEM('E&xit'),USE(?Exit),MSG('Exit this application'),STD(STD:Close)
              END
              ITEM('Open Test Window'),USE(?itmStart)  ! Menu item to open the timer demo window
            END
          END
  CODE
  OPEN(AppFrame)  ! Open the main application window
  
  ! Main application event loop
  ACCEPT
    Case Accepted()
    OF ?itmStart
      START(TimerWindow,25000)  ! Start the timer demo window as a separate thread
    OF ?Exit
      BREAK  ! Exit the application
    END
  END
  
  CLOSE(AppFrame)  ! Close the main application window
!---------------------------------------------------------------
! TimerWindow
!
! This procedure demonstrates the use of two WinMMTimer instances
! with different intervals to update two progress bars
! - MyTimer1: Event-driven timer, handled via NOTIFY in the ACCEPT loop
! - MyTimer2: Inline timer, handled by deriving OnTick()  
!---------------------------------------------------------------
TimerWindow   PROCEDURE()

! Create two timer instances
MyTimer1  WinMMTimerClass  ! Fast timer (10ms)
MyTimer2        CLASS(WinMMTimerClass)  ! Slow timer (50ms)
OnTick            PROCEDURE(),SIGNED,DERIVED
                END


! Window with two progress bars to demonstrate the timers
TimerWindow          WINDOW('Two timers demo'),AT(,,395,113),MDI,GRAY,SYSTEM,FONT('Segoe UI',9)
                  BUTTON('Start'),AT(254,87,41,19),USE(?OkButton),DEFAULT
                  BUTTON('Close'),AT(303,87,42,19),USE(?CancelButton)
    ! Progress bar for fast timer
                  PROGRESS,AT(56,14,289,30),USE(?PROGRESS1),RANGE(0,100)
    ! Progress bar for slow timer
                  PROGRESS,AT(56,54,289,30),USE(?PROGRESS2),RANGE(0,100)
                END

! Variables for notification handling
DbgStr    CSTRING(256)
NCode     UNSIGNED  ! Notification code received
NParam    LONG      ! Notification parameter

! Custom notification codes for our timers
NOTIFY:FastTick   EQUATE(1001)  ! Notification code for fast timer
NOTIFY:SlowTick   EQUATE(1002)  ! Notification code for slow timer code shows it's not used

! Variables to track progress bar positions
Count1    LONG(0)     ! Counter for first progress bar
Count2    LONG(0)     ! Counter for second progress bar
Dir1      SIGNED(1)   ! Direction for first progress bar (1 = up, -1 = down)
Dir2      SIGNED(1)   ! Direction for second progress bar
MaxValue  LONG(100)   ! Maximum value for progress bars
!---------------------------------------------------------------
  CODE
  OPEN(TimerWindow)  ! Open the timer demo window

  ! Set range for both progress bars
  ?PROGRESS1{PROP:RangeHigh} = MaxValue
  ?PROGRESS2{PROP:RangeHigh} = MaxValue

  ! Main window event loop
  ACCEPT
    CASE ACCEPTED()
    OF ?OkButton
      ! Handle the Start/Pause/Resume button
      CASE ?OkButton{prop:text}
      OF 'Start'
        ! Start two timers with different intervals:
        MyTimer1.Start(10, TimerWindow, NOTIFY:FastTick)   ! 10 ms interval (fast timer)
        MyTimer2.Start(50, TimerWindow, NOTIFY:SlowTick)   ! 50 ms interval (slow timer)
        ?OkButton{prop:text} = 'Pause'  ! Change button text to Pause
      OF 'Pause'
        ! Pause both timers
        MyTimer1.Pause()
        MyTimer2.Pause()
        ?OkButton{prop:text} = 'Resume'  ! Change button text to Resume
      OF 'Resume'
        ! Resume both timers
        MyTimer1.Resume()
        MyTimer2.Resume()
        ?OkButton{prop:text} = 'Pause'  ! Change button text back to Pause
      END
    OF ?CancelButton
      BREAK  ! Close the window
    END

    CASE EVENT()
    OF EVENT:Notify
      ! Handle timer notifications
      IF NOTIFICATION(NCode,,NParam)
        CASE NCode
        OF NOTIFY:FastTick
          ! Update first progress bar (fast timer)
          Count1 += Dir1
          IF Count1 >= MaxValue
            Count1 = MaxValue
            Dir1 = -1
          ELSIF Count1 <= 0
            Count1 = 0
            Dir1 = 1
          END
          ?PROGRESS1{PROP:Progress} = Count1
        OF NOTIFY:SlowTick
          ! MyTimer2 is handled by OnTick, so we don’t need NOTIFY:SlowTick here
        END
      END
    END
  END
  ! Cleanup happens automatically in the Destruct methods of the timer objects

MyTimer2.OnTick   Procedure()
  CODE

  Count2 += Dir2
  IF Count2 >= MaxValue
    Count2 = MaxValue
    Dir2 = -1
  ELSIF Count2 <= 0
    Count2 = 0
    Dir2 = 1
  END
  ?PROGRESS2{PROP:Progress} = Count2
  RETURN Level:Benign  ! Suppress NOTIFY (handled here)