Attribute VB_Name = "NavKey"
'***************************************************************************
'Navigation Key Handler (including automated tab order handling)
'Copyright 2017-2021 by Tanner Helland
'Created: 18/August/17
'Last updated: 25/August/21
'Last update: fix potential crash when unloading Options dialog
'
'In a project as complex as PD, tab order is difficult to keep straight.  VB orders controls in the order
' they're added, and there's no easy way to modify this short of manually setting TabOrder across all forms.
' Worse still, many PD usercontrols are actually several controls condensed into one, so they need to manage
' their own internal tab order.
'
'To try and remedy this, PD now uses a homebrew tab order manager.  When a form is loaded, it notifies this
' module of the names and hWnds of all child controls.  This module manages that list internally, and when
' tab commands are raised, this module can be queried to figure out where to send focus.
'
'Similarly, this form automatically orders controls in L-R, T-B order, and because position is calculated at
' run-time, we never have to worry about order being incorrect!
'
'Finally, things like command bar "OK" and "Cancel" buttons are automatically flagged, so we can support
' "Default" and "Cancel" commands on each dialog.  Individual dialogs don't have to manage any of this.
'
'Unless otherwise noted, all source code in this file is shared under a simplified BSD license.
' Full license details are available in the LICENSE.md file, or at https://photodemon.org/license/
'
'***************************************************************************

Option Explicit

'Remember: when passing messages to PD controls, do not call PostMessage directly, as it sends
' messages to the thread's message queue.  Instead, asynchronously relay messages to target windows
' via SendNotifyMessage.
Private Declare Function SendNotifyMessage Lib "user32" Alias "SendNotifyMessageW" (ByVal hWnd As Long, ByVal wMsg As Long, ByVal wParam As Long, ByVal lParam As Long) As Long

Private Const INIT_NUM_OF_FORMS As Long = 8
Private m_Forms() As pdObjectList
Private m_NumOfForms As Long, m_LastForm As Long

'Before loading individual controls, notify this module of the parent form preceding the loop.  (This improves
' performance because we don't have to look-up the form in our table for subsequent calls.)
Public Sub NotifyFormLoading(ByRef parentForm As Form, ByVal handleAutoResize As Boolean, Optional ByVal hWndCustomAnchor As Long = 0)

    'At present, PD guarantees that *most* forms will not be double-loaded - e.g. only one instance
    ' is allowed for effect and adjustment dialogs.
    '
    'One weird exception to this rule is the main form, who may be re-themed more than once if the
    ' user does something like change the active language at run-time (which requires a re-theme
    ' because UI layout may change dramatically).  Its child forms may be re-themed as part of the
    ' process (e.g. toolbars).
    '
    'As such, we do need to perform a failsafe check for the specified form in our table, even though
    ' 99.9% of the time such a check is unnecessary.
    If (Not parentForm Is Nothing) Then
        
        'Make sure we have room for this form (expanding the collection is harmless, even if we
        ' find a match for this form in the collection)
        If (m_NumOfForms = 0) Then
            ReDim m_Forms(0 To INIT_NUM_OF_FORMS - 1) As pdObjectList
        Else
            If (m_NumOfForms > UBound(m_Forms)) Then ReDim Preserve m_Forms(0 To m_NumOfForms * 2 - 1) As pdObjectList
        End If
        
        'Perform a quick failsafe check for the current form existing in the collection.
        Dim targetIndex As Long
        If (m_NumOfForms <> 0) Then
            
            Dim i As Long
            For i = 0 To m_NumOfForms - 1
                If (Not m_Forms(i) Is Nothing) Then
                    If (m_Forms(i).GetParentHWnd = parentForm.hWnd) Then
                        targetIndex = i
                        Exit For
                    End If
                End If
            Next i
            
        Else
            targetIndex = m_NumOfForms
        End If
        
        Set m_Forms(targetIndex) = New pdObjectList
        m_Forms(targetIndex).SetParentHWnd parentForm.hWnd, handleAutoResize, hWndCustomAnchor
        
        m_LastForm = targetIndex
        If (targetIndex = m_NumOfForms) Then m_NumOfForms = m_NumOfForms + 1
        
    End If

End Sub

Public Sub NotifyFormUnloading(ByRef parentForm As Form)

    'Find the matching form in our object list
    If (m_NumOfForms > 0) Then
        
        Dim targetHWnd As Long
        targetHWnd = parentForm.hWnd
        
        Dim i As Long, indexOfForm As Long
        For i = 0 To m_NumOfForms - 1
            If (Not m_Forms(i) Is Nothing) Then
                If (m_Forms(i).GetParentHWnd = targetHWnd) Then
                    
                    'Want to know what this collection tracked?  Use the helpful "PrintDebugList()" function.
                    'm_Forms(i).PrintDebugList
                    
                    Set m_Forms(i) = Nothing
                    indexOfForm = i
                    Exit For
                    
                End If
            End If
        Next i
        
        'If we removed this from the middle of the list, shift subsequent entries down
        If (indexOfForm < m_NumOfForms - 1) Then
            m_NumOfForms = m_NumOfForms - 1
            For i = indexOfForm To m_NumOfForms - 1
                Set m_Forms(i) = m_Forms(i + 1)
            Next i
            Set m_Forms(m_NumOfForms) = Nothing
        End If
        
    End If
    

End Sub

'After calling NotifyFormLoading(), above, you can proceed to notify us of all child controls.
Public Sub NotifyControlLoad(ByRef childObject As Object, Optional ByVal hostFormhWnd As Long = 0, Optional ByVal canReceiveFocus As Boolean = True)
    
    'If no parent window handle is specified, assume the last form
    If (hostFormhWnd = 0) Then
        If (Not m_Forms(m_LastForm) Is Nothing) Then m_Forms(m_LastForm).NotifyChildControl childObject, canReceiveFocus
    
    'The caller specified a parent window handle.  Find a matching object before continuing.
    Else
        
        'Failsafe checks follow
        If (m_NumOfForms > 0) And (m_LastForm < UBound(m_Forms)) Then
            If (Not m_Forms(m_LastForm) Is Nothing) Then
                
                If (m_Forms(m_LastForm).GetParentHWnd = hostFormhWnd) Then
                    m_Forms(m_LastForm).NotifyChildControl childObject, canReceiveFocus
                Else
                
                    Dim i As Long
                    For i = 0 To m_NumOfForms - 1
                        If (m_Forms(i).GetParentHWnd = hostFormhWnd) Then
                            m_Forms(i).NotifyChildControl childObject, canReceiveFocus
                            Exit For
                        End If
                    Next i
                
                End If
            
            '/failsafe check for m_Forms(m_LastForm) Is Nothing
            End If
        '/failsafe check for form index exists in form array
        End If
    
    End If
    
End Sub

'When a PD control receives a "navigation" keypress (Enter, Esc, Tab), relay it to this function to activate
' automatic handling.  (For example, Enter will trigger a command bar "OK" press, if a command bar is present
' on the same dialog as the child object.)
Public Function NotifyNavKeypress(ByRef childObject As Object, ByVal navKeyCode As PD_NavigationKey, ByVal Shift As ShiftConstants) As Boolean
    
    NotifyNavKeypress = False
    
    Dim formIndex As Long, childHwnd As Long
    formIndex = -1
    childHwnd = childObject.hWnd
    
    Dim targetHWnd As Long
    
    'First, search the LastForm object for a hit.  (In most cases, that form will be the currently active form,
    ' and it shortcuts the search process to go there first.)
    If (m_LastForm <> 0) Then
        If (Not m_Forms(m_LastForm) Is Nothing) Then
            If m_Forms(m_LastForm).DoesHWndExist(childHwnd) Then formIndex = m_LastForm
        End If
    End If
    
    'If we didn't find the hWnd in our last-activated form, try other forms until we get a hit
    If (formIndex = -1) Then
        
        Dim i As Long
        For i = 0 To m_NumOfForms - 1
        
            'Normally, we would never expect to encounter a null entry here, but as a failsafe against forms
            ' unloading incorrectly (especially if we ever implement plugins), check for null objects
            If (Not m_Forms(i) Is Nothing) Then
            
                'While we're here, update m_LastForm to match - it may improve performance on subsequent matches
                If m_Forms(i).DoesHWndExist(childHwnd) Then
                    formIndex = i
                    m_LastForm = formIndex
                    Exit For
                End If
                
            End If
            
        Next i
        
    End If
    
    'It should be physically impossible to *not* have a form index by now, but better safe than sorry.
    If (formIndex >= 0) Then
        
        'For Enter and Esc keypresses, we want to see if the target form contains a command bar.  If it does,
        ' we'll directly invoke the appropriate keypress.
        If (navKeyCode = pdnk_Enter) Or (navKeyCode = pdnk_Escape) Then
            
            'See if this form 1) is a raised dialog, and 2) contains a command bar
            If Interface.IsModalDialogActive() Then
            
                If m_Forms(formIndex).DoesTypeOfControlExist(pdct_CommandBar) Then
                
                    'It does!  Grab the hWnd and forward the relevant window message to it
                    targetHWnd = m_Forms(formIndex).GetFirstHWndForType(pdct_CommandBar)
                    SendNotifyMessage targetHWnd, WM_PD_DIALOG_NAVKEY, navKeyCode, 0&
                    NotifyNavKeypress = True
                
                'If a command bar doesn't exist, look for a "mini command bar" instead
                ElseIf m_Forms(formIndex).DoesTypeOfControlExist(pdct_CommandBarMini) Then
                    targetHWnd = m_Forms(formIndex).GetFirstHWndForType(pdct_CommandBarMini)
                    SendNotifyMessage targetHWnd, WM_PD_DIALOG_NAVKEY, navKeyCode, 0&
                    NotifyNavKeypress = True
                    
                'No command bar exists on this form, which is fine - this could be a toolpanel, for example.
                ' As such, there's nothing we need to do.
                End If
            
            'If a modal dialog is *not* active, let the caller handle Enter/Esc presses on their own
            Else
                NotifyNavKeypress = False
            End If
        
        'The only other supported key (at this point) is TAB.  Tab keypresses are handled by the object list;
        ' it's responsible for figuring out which control is next in order.
        Else
            m_Forms(formIndex).NotifyTabKey childHwnd, ((Shift And vbShiftMask) <> 0)
            NotifyNavKeypress = True
        End If
        
    Else
        Debug.Print "WARNING!  NavKey.NotifyNavKeypress couldn't find this control in its collection.  How is this possible?"
    End If

End Function

