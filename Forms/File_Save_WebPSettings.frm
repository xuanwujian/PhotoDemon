VERSION 5.00
Begin VB.Form dialog_ExportWebP 
   BackColor       =   &H80000005&
   BorderStyle     =   4  'Fixed ToolWindow
   Caption         =   " WebP Export Options"
   ClientHeight    =   6585
   ClientLeft      =   45
   ClientTop       =   285
   ClientWidth     =   12135
   BeginProperty Font 
      Name            =   "Tahoma"
      Size            =   8.25
      Charset         =   0
      Weight          =   400
      Underline       =   0   'False
      Italic          =   0   'False
      Strikethrough   =   0   'False
   EndProperty
   LinkTopic       =   "Form1"
   MaxButton       =   0   'False
   MinButton       =   0   'False
   ScaleHeight     =   439
   ScaleMode       =   3  'Pixel
   ScaleWidth      =   809
   ShowInTaskbar   =   0   'False
   Begin PhotoDemon.commandBar cmdBar 
      Align           =   2  'Align Bottom
      Height          =   750
      Left            =   0
      TabIndex        =   0
      Top             =   5835
      Width           =   12135
      _ExtentX        =   21405
      _ExtentY        =   1323
      BackColor       =   14802140
      dontAutoUnloadParent=   -1  'True
   End
   Begin PhotoDemon.fxPreviewCtl fxPreview 
      Height          =   5625
      Left            =   120
      TabIndex        =   1
      Top             =   120
      Width           =   5625
      _ExtentX        =   9922
      _ExtentY        =   9922
   End
   Begin PhotoDemon.pdComboBox cboSaveQuality 
      Height          =   375
      Left            =   6240
      TabIndex        =   2
      Top             =   2400
      Width           =   5655
      _ExtentX        =   9975
      _ExtentY        =   661
   End
   Begin PhotoDemon.sliderTextCombo sltQuality 
      Height          =   405
      Left            =   6120
      TabIndex        =   3
      Top             =   3000
      Width           =   5775
      _ExtentX        =   15055
      _ExtentY        =   873
      Min             =   1
      Max             =   256
      Value           =   16
      NotchPosition   =   1
   End
   Begin PhotoDemon.pdLabel lblBefore 
      Height          =   435
      Left            =   6240
      Top             =   3480
      Width           =   2265
      _ExtentX        =   3995
      _ExtentY        =   767
      Caption         =   "high quality, large file"
      FontItalic      =   -1  'True
      FontSize        =   8
      ForeColor       =   4210752
      Layout          =   1
   End
   Begin PhotoDemon.pdLabel lblAfter 
      Height          =   435
      Left            =   8520
      Top             =   3480
      Width           =   2190
      _ExtentX        =   3863
      _ExtentY        =   767
      Alignment       =   1
      Caption         =   "low quality, small file"
      FontItalic      =   -1  'True
      FontSize        =   8
      ForeColor       =   4210752
      Layout          =   1
   End
   Begin PhotoDemon.pdLabel lblTitle 
      Height          =   360
      Index           =   0
      Left            =   6000
      Top             =   2040
      Width           =   5850
      _ExtentX        =   10319
      _ExtentY        =   635
      Caption         =   "image compression ratio"
      FontSize        =   12
      ForeColor       =   4210752
   End
End
Attribute VB_Name = "dialog_ExportWebP"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
'***************************************************************************
'Google WebP Export Dialog
'Copyright 2014-2016 by Tanner Helland
'Created: 14/February/14
'Last updated: 14/February/14
'Last update: initial build
'
'Dialog for presenting the user a number of options related to WebP exporting.  Obviously this feature
' relies on FreeImage, and WebP support will be disabled if FreeImage cannot be found.
'
'All source code in this file is licensed under a modified BSD license.  This means you may use the code in your own
' projects IF you provide attribution.  For more information, please visit http://photodemon.org/about/license/
'
'***************************************************************************

Option Explicit

'The user input from the dialog
Private userAnswer As VbMsgBoxResult

'This form can be notified of the image being exported.  This may be used in the future to provide a preview.
Public imageBeingExported As pdImage

'When rendering the preview, we don't want to always re-request a copy of the main image.  Instead, we
' store one in this DIB (at the size of the preview) and simply re-use it when we need to render a preview.
Private origImageCopy As pdDIB

'The user's answer is returned via this property
Public Property Get DialogResult() As VbMsgBoxResult
    DialogResult = userAnswer
End Property

'QUALITY combo box - when adjusted, change the scroll bar to match
Private Sub cboSaveQuality_Click()
    
    Select Case cboSaveQuality.ListIndex
        
        Case 0
            sltQuality = 100
                
        Case 1
            sltQuality = 80
                
        Case 2
            sltQuality = 60
                
        Case 3
            sltQuality = 40
                
        Case 4
            sltQuality = 20
                
    End Select
    
End Sub

Private Sub cmdBar_CancelClick()
    userAnswer = vbCancel
    Me.Hide
End Sub

Private Sub cmdBar_OKClick()

    'Determine the compression ratio for the WebP transform
    If sltQuality.IsValid Then
        g_WebPCompression = Abs(sltQuality)
    Else
        Exit Sub
    End If
     
    userAnswer = vbOK
    Me.Hide

End Sub

Private Sub cmdBar_RequestPreviewUpdate()
    UpdatePreview
End Sub

Private Sub cmdBar_ResetClick()
    cboSaveQuality.ListIndex = 1
End Sub

Private Sub Form_Unload(Cancel As Integer)
    ReleaseFormTheming Me
End Sub

Private Sub fxPreview_ViewportChanged()
    UpdatePreview
End Sub

Private Sub sltQuality_Change()
    updateComboBox
    UpdatePreview
End Sub

'Used to keep the "compression ratio" text box, scroll bar, and combo box in sync
Private Sub updateComboBox()
    
    Select Case sltQuality.Value
        
        Case 100
            If cboSaveQuality.ListIndex <> 0 Then cboSaveQuality.ListIndex = 0
                
        Case 80
            If cboSaveQuality.ListIndex <> 1 Then cboSaveQuality.ListIndex = 1
                
        Case 60
            If cboSaveQuality.ListIndex <> 2 Then cboSaveQuality.ListIndex = 2
                
        Case 40
            If cboSaveQuality.ListIndex <> 3 Then cboSaveQuality.ListIndex = 3
                
        Case 20
            If cboSaveQuality.ListIndex <> 4 Then cboSaveQuality.ListIndex = 4
                
        Case Else
            If cboSaveQuality.ListIndex <> 5 Then cboSaveQuality.ListIndex = 5
                
    End Select
    
End Sub

'The ShowDialog routine presents the user with this form.
Public Sub showDialog()

    'Provide a default answer of "cancel" (in the event that the user clicks the "x" button in the top-right)
    userAnswer = vbCancel
    
    'Make sure that the proper cursor is set
    Screen.MousePointer = 0
    
    'Populate the quality drop-down box with presets corresponding to the WebP file format
    cboSaveQuality.Clear
    cboSaveQuality.AddItem " Lossless (100)", 0
    cboSaveQuality.AddItem " Low compression, good image quality (80)", 1
    cboSaveQuality.AddItem " Moderate compression, medium image quality (60)", 2
    cboSaveQuality.AddItem " High compression, poor image quality (40)", 3
    cboSaveQuality.AddItem " Super compression, very poor image quality (20)", 4
    cboSaveQuality.AddItem " Custom ratio (X:1)", 5
    cboSaveQuality.ListIndex = 0
    
    Message "Waiting for user to specify WebP export options... "
    
    'Apply translations and visual themes
    ApplyThemeAndTranslations Me
    
    'Retrieve a composited version of the target image
    Set origImageCopy = New pdDIB
    imageBeingExported.getCompositedImage origImageCopy, True
    
    'Update the preview
    UpdatePreview
    
    'Display the dialog
    ShowPDDialog vbModal, Me, True

End Sub

'Render a new WebP preview
Private Sub UpdatePreview()

    If cmdBar.previewsAllowed And g_ImageFormats.FreeImageEnabled And sltQuality.IsValid Then
        
        'Start by retrieving the relevant portion of the image, according to the preview window
        Dim tmpSafeArray As SAFEARRAY2D
        previewNonStandardImage tmpSafeArray, origImageCopy, fxPreview
        
        'The public workingDIB object now contains the relevant portion of the preview window.  Use that to
        ' obtain a JPEG-ified version of the image data.
        fillDIBWithWebPVersion workingDIB, workingDIB, Abs(sltQuality.Value)
                
        'Paint the final image to screen and release all temporary objects
        finalizeNonstandardPreview fxPreview
        
    End If

End Sub
