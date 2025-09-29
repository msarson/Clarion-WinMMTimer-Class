# WinMMTimer - High-Precision Timer for Clarion Applications

## Overview

WinMMTimer is a high-precision timer class for Clarion applications that provides millisecond-level timing accuracy. It uses the Windows Multimedia Timer API to achieve more precise timing than standard Clarion timers, making it suitable for applications that require accurate timing intervals.

## Features

- **High-precision timing**: Millisecond-level accuracy using the Windows Multimedia Timer API
- **Simple interface**: Easy to use with standard Clarion notification mechanism
- **Multiple timers**: Support for multiple timer instances in the same window
- **Thread-safe**: Properly handles timer events across threads
- **Pause/Resume**: Ability to pause and resume timers without losing settings

## Files

- `WinMMTimer.inc` - Class and type definitions
- `WinMMTimer.clw` - Implementation of the timer classes
- `TimerTest.clw` - Example application demonstrating timer usage

## Usage

### Basic Usage

1. Include the WinMMTimer header in your application:
   ```clarion
   INCLUDE('WinMMTimer.inc'),ONCE
   ```

2. Declare a timer instance in your procedure:
   ```clarion
   MyTimer  WinMMTimerClass
   ```

3. Start the timer with desired parameters:
   ```clarion
   MyTimer.Start(interval, window, notifyCode[, param])
   ```
   Where:
   - `interval` is the timer interval in milliseconds
   - `window` is the window to receive notifications
   - `notifyCode` is the notification code to send
   - `param` is an optional user parameter (default 0)

4. Handle timer notifications in your event loop:
   ```clarion
   CASE EVENT()
   OF EVENT:Notify
     IF NOTIFICATION(NCode,,NParam)
       CASE NCode
       OF MY_TIMER_CODE
         ! Handle timer event
       END
     END
   END
   ```

5. Stop the timer when done:
   ```clarion
   MyTimer.Stop()
   ```

### Timer Control Methods

- **Start**: `MyTimer.Start(interval, window, notifyCode[, param])`
  Starts the timer with the specified parameters.

- **Pause**: `MyTimer.Pause()`
  Temporarily pauses the timer without losing settings.

- **Resume**: `MyTimer.Resume()`
  Resumes a previously paused timer.

- **Stop**: `MyTimer.Stop()`
  Completely stops the timer and cleans up resources.

- **HandleMessage**: `MyTimer.HandleMessage()`
  Processes timer notifications. This method is declared as VIRTUAL, allowing you to override it in derived classes to customize notification handling.

## Example

The included `TimerTest.clw` demonstrates how to use the WinMMTimer class with two timers running at different intervals:

```clarion
! Create timer instances
MyTimer1  WinMMTimerClass
MyTimer2  WinMMTimerClass

! Start timers with different intervals
MyTimer1.Start(10, Window, NOTIFY:FastTick)   ! 10 ms interval
MyTimer2.Start(50, Window, NOTIFY:SlowTick)   ! 50 ms interval

! Handle timer notifications
CASE EVENT()
OF EVENT:Notify
  IF NOTIFICATION(NCode,,NParam)
    CASE NCode
    OF NOTIFY:FastTick
      ! Handle fast timer event
    OF NOTIFY:SlowTick
      ! Handle slow timer event
    END
  END
END

! Stop timers when done
MyTimer1.Stop()
MyTimer2.Stop()
```

## Technical Details

### How It Works

1. The timer uses the Windows Multimedia Timer API (`timeSetEvent`) to create a high-precision timer.
2. When the timer fires, it posts a custom message to the specified window.
3. The window procedure is subclassed to intercept this custom message.
4. When the custom message is received, the timer calls the `NOTIFY` mechanism to notify the application.
5. The application handles the notification in its event loop.

### Thread Safety

The timer registry uses a critical section to ensure thread safety when multiple timers are used across different threads.

### Memory Management

All resources are automatically cleaned up in the destructor methods, so you don't need to worry about memory leaks.

### Extending the Timer Class

The `HandleMessage` method is declared as VIRTUAL, which means you can create a derived class that overrides this method to implement custom notification handling:

```clarion
MyCustomTimer CLASS(WinMMTimerClass)
HandleMessage PROCEDURE(),VIRTUAL
             END

MyCustomTimer.HandleMessage PROCEDURE()
  CODE
  ! Custom notification handling
  ! You can still call the parent method if needed:
  PARENT.HandleMessage()
  
  ! Additional custom processing
  DoSomethingElse()
END
```

## Requirements

- Clarion 6.3 or later
- Windows operating system

## License

This code is provided as-is for use in Clarion applications.