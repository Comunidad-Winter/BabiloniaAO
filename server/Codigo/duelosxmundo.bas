Attribute VB_Name = "duelosxmundo"
Option Explicit
 
Public Type userDuelos
        OtherIndex    As Integer        'UserIndex target.
        ForTheWorld   As Boolean        '�Tiene duelo?
End Type
 
Public Sub Duelos_IniciarDuelo(ByVal SendIndex As Integer, ByVal targetIndex As Integer)
 
' \  Note    :  Envia/Inicia un duelo "por el mundo"
' \  Author  :  maTih.-
 
'Si los dos enviaron el comando entonces inicia el duelo
 
If UserList(SendIndex).nDuel.OtherIndex = targetIndex And UserList(targetIndex).nDuel.OtherIndex = SendIndex Then
 
   'Seteamos flags.
   UserList(SendIndex).nDuel.ForTheWorld = True
   UserList(targetIndex).nDuel.ForTheWorld = True
   
   WriteConsoleMsg SendIndex, "El duelo ha iniciado!", FontTypeNames.FONTTYPE_CITIZEN
   WriteConsoleMsg targetIndex, "El duelo ha iniciado!", FontTypeNames.FONTTYPE_CITIZEN
 
Else            'Si es el primero en usar el comando.
 
   'Seteamos el targetUser como SendIndex, para que directamente ponga /DUELO.
   UserList(targetIndex).flags.TargetUser = SendIndex
   
   WriteConsoleMsg targetIndex, UserList(SendIndex).name & " Quiere combatir en un duelo aqu� y ahora, aceptas? tipea /DUELO", FontTypeNames.FONTTYPE_CITIZEN
   WriteConsoleMsg SendIndex, "Se ha enviado la solicitud.", FontTypeNames.FONTTYPE_CITIZEN
End If
 
End Sub
 
Public Sub Duelos_TerminarDuelo(ByVal Ganador As Integer, ByVal Perdedor As Integer, Optional ByVal CambioMapa As Boolean = False, Optional ByVal Desconexion As Boolean = False)
 
' \  Note    :  Terminamos el duelo.
' \  Author  :  maTih.-
 
Dim GanadorString       As String
Dim PerdedorString      As String
 
'Reset user variables
UserList(Ganador).nDuel.ForTheWorld = False
UserList(Perdedor).nDuel.ForTheWorld = False
 
UserList(Ganador).nDuel.OtherIndex = 0
UserList(Perdedor).nDuel.OtherIndex = 0
 
'Strings by default.
GanadorString = "Ganaste el duelo!"
PerdedorString = "Perdiste el duelo!"
 
'Seteamos los string si cambi� de mapa.
If CambioMapa Then
GanadorString = "Ganaste el duelo por que el otro usuario [" & UserList(Perdedor).name & "] cambi� de mapa."
PerdedorString = "Perdiste el duelo por escaparte del mapa!!"
End If
 
'Seteamos los strings si se desconect�.
If Desconexion Then
    GanadorString = "Ganaste el duelo por que el otro usuario [" & UserList(Perdedor).name & "] se desconect�."
    PerdedorString = vbNullString
End If
 
WriteConsoleMsg Ganador, GanadorString, FontTypeNames.FONTTYPE_GUILD
 
If PerdedorString <> vbNullString Then
    WriteConsoleMsg Perdedor, PerdedorString, FontTypeNames.FONTTYPE_GUILD
End If
 
End Sub
 
Public Function Duelos_IndexsPueden(ByVal I1 As Integer, ByVal I2 As Integer, dummyString As String) As Boolean
 
' \  Note    :  Devuelve una variable booleana dependiendo si puede/o no iniciarse el duelo
' \  Author  :  maTih.-
 
Duelos_IndexsPueden = False
 
'No puede con el mismo index.
 
If I1 = I2 Then
   dummyString = "No puedes duelear con tu mismo!"
   Exit Function
End If
 
With UserList(I1)
 
'Est� muerto?
 
If .flags.Muerto Then
   dummyString = "Est�s muerto!!"
   Exit Function
End If
 
'Est� preso?
 
If .Counters.Pena > 0 Then
   dummyString = "Est�s en la carcel!!"
   Exit Function
End If
 
End With
 
With UserList(I2)
 
'Est� muerto?
 
If .flags.Muerto Then
   dummyString = "Est� muerto!!"
   Exit Function
End If
 
'Est� preso?
 
If .Counters.Pena > 0 Then
   dummyString = "Est� en la carcel!!"
   Exit Function
End If
 
End With
 
Duelos_IndexsPueden = True
 
End Function
 
Public Function Duelos_UsuariosEnDuelo(ByVal I1 As Integer, ByVal I2 As Integer) As Boolean
 
' \  Note    :  Devuelve una variable booleana si I1 Esta dueleando CON I2
' \  Author  :  maTih.-
 
'Si ambos est�n dueleando
 
If (UserList(I1).nDuel.ForTheWorld) And (UserList(I2).nDuel.ForTheWorld) Then
 
    If (UserList(I1).nDuel.OtherIndex = I2) And (UserList(I2).nDuel.OtherIndex = I1) Then
        Duelos_UsuariosEnDuelo = True
        Exit Function
    End If
   
End If
 
Duelos_UsuariosEnDuelo = False
 
End Function
