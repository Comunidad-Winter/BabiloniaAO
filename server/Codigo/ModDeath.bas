Attribute VB_Name = "ModDeath"
 
Option Explicit
 
'Programado por Ivan.-
 
Type DeathUser
     UserIndex      As Integer      'UI del usuario.
     LastPosition   As WorldPos     'Pos que estaba antes de entrar.
     Esperando      As Byte         'Tiempo de espera para volver.
End Type
 
Type tDeath
     Cupos          As Byte         'Cantidad de cupos.
     Ingresaron     As Byte         'Cantidad que ingreso.
     Usuarios()     As DeathUser    'Tipo de usuarios
     Cuenta         As Byte         'Cuenta regresiva.
     Activo         As Boolean      'Hay deathmatch
     CaenObjs       As Boolean      'Caen objetos.
     AutoCancelTime As Byte         'Tiempo de auto-cancelamiento
     Ganador        As DeathUser    'Datos del ganador.
     BanqueroIndex  As Integer      'NPCindex del banquero..
End Type
 
Const CUENTA_NUM    As Byte = 5     'Segundos de cuenta.
Const ARENA_MAP     As Integer = 292 'Mapa de la arena.
Const ARENA_X       As Byte = 22   'X de la arena(se suma por usuario)
Const ARENA_Y       As Byte = 40    'Y de la arena.
Const BANCO_X       As Byte = 50    'X donde aparece el banquero.
Const BANCO_Y       As Byte = 51    'Y Donde aparece el banquro.
 
Const PREMIO_POR_CABEZA As Long = 1000000 'Premio en oro , el cálculo es el de acá abajo.
Const TIEMPO_AUTOCANCEL As Byte = 180     '3 Minutos antes del auto-cancel.
Const TIEMPO_PARAVOLVER As Byte = 120     '2 Minutos para lukear objetos.
 
'Cálculo : PREMIO_POR_CABEZA * JUGADORES QUE PARTICIPARON
 
Public DeathMatch   As tDeath
 
Sub Limpiar()
 
' @ Limpia los datos anteriores.
 
Dim DumpPos     As WorldPos
Dim loopX       As Long
Dim LoopY       As Long
Dim esSalida    As Boolean
 
With DeathMatch
     .Cuenta = 0
     .Cupos = 0
     .Ingresaron = 0
     .Activo = False
     .CaenObjs = False
     
     'NPC Banquero invocado?
     If .BanqueroIndex <> 0 Then
        'Nos aseguramos de que esté invocado, con esto : P
        If Npclist(.BanqueroIndex).Numero <> 0 Then
           'Lo borramos.
           QuitarNPC .BanqueroIndex
        End If
     End If
     
     .BanqueroIndex = 0
     
     'Limpio el tipo de ganador.
     With .Ganador
          .UserIndex = 0
          .LastPosition = DumpPos
          .Esperando = 0
     End With
     
     'Limpia los objetos que quedaron tira2.
     For loopX = 1 To 100
         For LoopY = 1 To 100
             With MapData(ARENA_MAP, loopX, LoopY)
                  'Hay objeto?
                  If .ObjInfo.ObjIndex <> 0 Then
                     'Flag por si hay salida.
                     esSalida = (.TileExit.Map <> 0)
                     'No es del mapa.
                     If Not ItemNoEsDeMapa(.ObjInfo.ObjIndex, esSalida) Then
                        'Erase :P
                        Call EraseObj(.ObjInfo.Amount, ARENA_MAP, loopX, LoopY)
                     End If
                  End If
             End With
         Next LoopY
     Next loopX
     
End With
 
End Sub
 
Sub Cancelar(ByRef CancelatedBy As String)
 
' @ Cancela el death.
 
Dim loopX   As Long
Dim UIndex  As Integer
Dim UPos    As WorldPos
 
'Aviso.
SendData SendTarget.ToAll, 0, PrepareMessageConsoleMsg("Deathmatch > Cancelado por : " & CancelatedBy & ".", FontTypeNames.FONTTYPE_CITIZEN)
 
'Llevo los usuarios que entraron a ulla.
For loopX = 1 To UBound(DeathMatch.Usuarios())
    UIndex = DeathMatch.Usuarios(loopX).UserIndex
    'Hay usuario?
    If UIndex <> -1 Then
       'Está logeado?
       If UserList(UIndex).ConnID <> -1 Then
          'Está en death?
          If UserList(UIndex).Death Then
             'Telep to anterior posición.
             Call AnteriorPos(UIndex, UPos)
             WarpUserChar UIndex, UPos.Map, UPos.X, UPos.Y, True
             'Reset el flag.
             UserList(UIndex).Death = False
          End If
       End If
    End If
Next loopX
 
'Limpia el tipo
Limpiar
 
End Sub
 
Sub ActivarNuevo(ByRef OrganizatedBy As String, ByVal Cupos As Byte, ByVal CaenObjetos As Boolean)
 
' @ Crea nuevo deathmatch.
 
Dim loopX   As Long
 
'Limpia el tipo.
Limpiar
 
'Llena los datos nuevos.
With DeathMatch
     .Cupos = Cupos
     .Activo = True
     .CaenObjs = CaenObjetos
     
     'Redim array.
     ReDim .Usuarios(1 To Cupos) As DeathUser
     
     'Lleno el array con -1s
     For loopX = 1 To Cupos
         .Usuarios(loopX).UserIndex = -1
     Next loopX
     
     'Avisa al mundo.
     SendData SendTarget.ToAll, 0, PrepareMessageConsoleMsg("Deathmatch > Organizado : " & OrganizatedBy & " " & Cupos & " Cupos! para entrar /DEATH" & IIf(.CaenObjs, ", Cae el inventario!", "."), FontTypeNames.FONTTYPE_CITIZEN)
     SendData SendTarget.ToAll, 0, PrepareMessageConsoleMsg("Deathmatch > Quedan 3 minutos antes del auto-cancelamiento si no se llena el cupo.", FontTypeNames.FONTTYPE_CITIZEN)
     
     'Set el tiempo de auto-cancelación.
     .AutoCancelTime = TIEMPO_AUTOCANCEL
End With
 
End Sub
 
Sub Ingresar(ByVal UserIndex As Integer)
 
' @ Usuario ingresa al death.
 
Dim LibreSlot   As Byte
Dim SumarCount  As Boolean
 
LibreSlot = ProximoSlot(SumarCount)
 
'No hay slot.
If Not LibreSlot <> 0 Then Exit Sub
 
With DeathMatch
     'Hay que sumar?
     If SumarCount Then .Ingresaron = .Ingresaron + 1
     
     'Lleno el usuario.
     .Usuarios(LibreSlot).LastPosition = UserList(UserIndex).Pos
     .Usuarios(LibreSlot).UserIndex = UserIndex
     
     'Llevo a la arena.
     WarpUserChar UserIndex, ARENA_MAP, ARENA_X, ARENA_Y, True
     
     'Aviso..
     WriteConsoleMsg UserIndex, "Has ingresado al deathmatch, eres el participante nº" & LibreSlot & ".", FontTypeNames.FONTTYPE_CITIZEN
     
     UserList(UserIndex).Death = True
     
     'Lleno el cupo?
     If .Ingresaron >= .Cupos Then
         'Quito el tiempo de auto-cancelación
         .AutoCancelTime = 0
         'Aviso que llenó el cupo
         SendData SendTarget.ToAll, 0, PrepareMessageConsoleMsg("DeathMatch > El cupo ha sido completado!", FontTypeNames.FONTTYPE_CITIZEN)
         'Doy inicio
         Iniciar
     End If
     
End With
 
End Sub
 
Sub Cuenta()
 
' @ Cuenta regresiva y auto-cancel acá.
 
Dim PacketToSend    As String
Dim CanSendPackage  As Boolean
 
With DeathMatch
     
    'Espera el ganador?
    If .Ganador.UserIndex <> 0 Then
       'Tiempo de espera
       If .Ganador.Esperando <> 0 Then
          'resta.
          .Ganador.Esperando = .Ganador.Esperando - 1
          'Llego al fin el tiempo.
          If Not .Ganador.Esperando <> 0 Then
             'Telep to anterior pos.
             WarpUserChar .Ganador.UserIndex, .Ganador.LastPosition.Map, .Ganador.LastPosition.X, .Ganador.LastPosition.Y, True
             'Aviso al usuario.
             WriteConsoleMsg .Ganador.UserIndex, "El tiempo ha llegado a su fin, fuiste devuelto a tu posición anterior", FontTypeNames.FONTTYPE_CITIZEN
             'Limpiar.
             Limpiar
          End If
        End If
    End If
   
    'Hay cuenta?
    If .Cuenta <> 0 Then
        'Resta el tiempo.
        .Cuenta = .Cuenta - 1
       
        If .Cuenta > 1 Then
            SendData SendTarget.toMap, ARENA_MAP, PrepareMessageConsoleMsg("El death iniciará en " & .Cuenta & " segundos.", FontTypeNames.FONTTYPE_CITIZEN)
        ElseIf .Cuenta = 1 Then
            SendData SendTarget.toMap, ARENA_MAP, PrepareMessageConsoleMsg("El death iniciará en 1 segundo!", FontTypeNames.FONTTYPE_CITIZEN)
        ElseIf .Cuenta <= 0 Then
            SendData SendTarget.toMap, ARENA_MAP, PrepareMessageConsoleMsg("El death inició! PELEEN!", FontTypeNames.FONTTYPE_CITIZEN)
            MapInfo(ARENA_MAP).Pk = True
        End If
    End If
   
    'Tiempo de auto-cancelamiento?
    If .AutoCancelTime <> 0 Then
       'Resto el contador
       If .AutoCancelTime <> 0 Then
           .AutoCancelTime = .AutoCancelTime - 1
       End If
             
       'Avisa cada 30 segundos.
       Select Case .AutoCancelTime
              Case 150      'Quedan 2:30.
                   CanSendPackage = True
                   PacketToSend = PrepareMessageConsoleMsg("Deathmatch > Auto-Cancelará en 2:30 minutos", FontTypeNames.FONTTYPE_CITIZEN)
              Case 120
                   CanSendPackage = True
                   PacketToSend = PrepareMessageConsoleMsg("Deathmatch > Auto-Cancelará en 2 minutos", FontTypeNames.FONTTYPE_CITIZEN)
              Case 90
                   CanSendPackage = True
                   PacketToSend = PrepareMessageConsoleMsg("Deathmatch > Auto-Cancelará en 1:30 minutos", FontTypeNames.FONTTYPE_CITIZEN)
              Case 60
                   CanSendPackage = True
                   PacketToSend = PrepareMessageConsoleMsg("Deathmatch > Auto-Cancelará en 1 minuto", FontTypeNames.FONTTYPE_CITIZEN)
              Case 30
                   CanSendPackage = True
                   PacketToSend = PrepareMessageConsoleMsg("Deathmatch > Auto-Cancelará en 30 segundos", FontTypeNames.FONTTYPE_CITIZEN)
              'Avisa a los 15
              Case 15
                   CanSendPackage = True
                   PacketToSend = PrepareMessageConsoleMsg("Deathmatch > Auto-Cancelará en 15 segundos", FontTypeNames.FONTTYPE_CITIZEN)
              'Avisa a los 10
              Case 10
                   CanSendPackage = True
                   PacketToSend = PrepareMessageConsoleMsg("Deathmatch > Auto-Cancelará en 10 segundos", FontTypeNames.FONTTYPE_CITIZEN)
              'Avisa a los 5
              Case 5
                   CanSendPackage = True
                   PacketToSend = PrepareMessageConsoleMsg("Deathmatch > Auto-Cancelará en 5 segundos", FontTypeNames.FONTTYPE_CITIZEN)
              'Avisa a los 3,2,1.
              Case 1, 2, 3
                   CanSendPackage = True
                   PacketToSend = PrepareMessageConsoleMsg("Deathmatch > Auto-Cancelará en " & .AutoCancelTime & " segundo/s", FontTypeNames.FONTTYPE_CITIZEN)
              Case 0
                   CanSendPackage = False
                   Call Cancelar("Falta de participantes.")
       End Select
       
       'Hay que enviar el mensaje?
       If CanSendPackage Then
          'Envia
          SendData SendTarget.ToAll, 0, PacketToSend
          'Reset el flag.
          CanSendPackage = False
       End If
       
    End If
   
End With
 
End Sub
 
Sub Iniciar()
 
' @ Inicia el evento.
 
Dim loopX   As Long
 
With DeathMatch
     
     'Set la cuenta.
     .Cuenta = CUENTA_NUM
     
     'Aviso a los usuarios.
     For loopX = 1 To UBound(.Usuarios())
         'Hay usuario?
         If .Usuarios(loopX).UserIndex <> -1 Then
            'Está logeado?
            If UserList(.Usuarios(loopX).UserIndex).ConnID <> -1 Then
               WriteConsoleMsg .Usuarios(loopX).UserIndex, "Llenó el cupo! El deathmatch iniciará en " & .Cuenta & " segundos!.", FontTypeNames.FONTTYPE_CITIZEN
            Else    'No loged, limpio el tipo
               .Usuarios(loopX).UserIndex = -1
            End If
         End If
     Next loopX
   
    'Por default el mapa es seguro..
    MapInfo(ARENA_MAP).Pk = False
     
End With
 
End Sub
 
Sub MuereUser(ByVal MuertoIndex As Integer)
 
' @ Muere usuario en dm.
 
Dim MuertoPos       As WorldPos
Dim QuedanEnDeath   As Byte
 
'Obtengo la anterior posición del usuario
Call AnteriorPos(MuertoIndex, MuertoPos)
 
'Si caen objetos pincho al usuario.
If DeathMatch.CaenObjs Then
   TirarTodosLosItems MuertoIndex
End If
 
'Revivir usuario
RevivirUsuario MuertoIndex
 
'Llenar vida.
UserList(MuertoIndex).Stats.MinHp = UserList(MuertoIndex).Stats.MaxHp
 
'Actualizar hp.
WriteUpdateHP MuertoIndex
 
'Reset el flag.
UserList(MuertoIndex).Death = False
 
'Telep anterior pos.
WarpUserChar MuertoIndex, MuertoPos.Map, MuertoPos.X, MuertoPos.Y, True
 
'Aviso al usuario
WriteConsoleMsg MuertoIndex, "Has caido en el deathMatch, has sido revivido y llevado a tu posición anterior (Mapa : " & MapInfo(MuertoPos.Map).name & ")", FontTypeNames.FONTTYPE_CITIZEN
 
'Aviso al mapa.
SendData SendTarget.toMap, ARENA_MAP, PrepareMessageConsoleMsg(UserList(MuertoIndex).name & " Ha sido derrotado.", FontTypeNames.FONTTYPE_CITIZEN)
 
'Obtengo los usuarios que quedan..
QuedanEnDeath = QuedanVivos()
 
'Queda 1?
If Not QuedanEnDeath <> 1 Then
   'Ganó ese usuario!
   Terminar
End If
   
End Sub
 
Sub Terminar()
 
' @ Termina el death y gana un usuario.
 
Dim winnerIndex As Integer
Dim GoldPremio  As Long
 
winnerIndex = GanadorIndex
 
'No hay ganador!! TRAGEDIAA XDD
If Not winnerIndex <> -1 Then
   SendData SendTarget.ToAdmins, 0, PrepareMessageConsoleMsg("TRAGEDIA EN DEATHMATCHS!! WINNERINDEX = -1!!!!", FontTypeNames.FONTTYPE_CITIZEN)
   Limpiar
   Exit Sub
End If
 
'Hay ganador, le doi el premio..
GoldPremio = (PREMIO_POR_CABEZA * DeathMatch.Cupos)
UserList(winnerIndex).Stats.GLD = UserList(winnerIndex).Stats.GLD + GoldPremio
 
'Actualizo el oro
WriteUpdateGold winnerIndex
 
With UserList(winnerIndex)
    'Aviso al mundo.
    SendData SendTarget.ToAll, 0, PrepareMessageConsoleMsg("Deathmatch > " & .name & " - " & ListaClases(.clase) & " " & ListaRazas(.raza) & " Nivel " & .Stats.ELV & " Ganó " & Format$(GoldPremio, "#,###") & " monedas de oro, " & IIf(DeathMatch.CaenObjs, "y los objetos recaudados", "") & " por salir primero en el evento.", FontTypeNames.FONTTYPE_CITIZEN)
End With
 
'Ganador a su anterior posición..
Dim ToPosition  As WorldPos
Call AnteriorPos(winnerIndex, ToPosition)
 
'Si era por objetos no lo llevo a la ciudad.
If DeathMatch.CaenObjs Then
   'Set los flags.
   DeathMatch.Ganador.LastPosition = ToPosition
   DeathMatch.Ganador.UserIndex = winnerIndex
   DeathMatch.Ganador.Esperando = TIEMPO_PARAVOLVER
   'Le aviso al pibe que va a tener tiempo de lukear y depositar.
   WriteConsoleMsg winnerIndex, "Tienes " & (TIEMPO_PARAVOLVER / 60) & " minutos para agarrar los objetos que desees.", FontTypeNames.FONTTYPE_CITIZEN
   WriteConsoleMsg winnerIndex, "Hay un banquero rondando este mapa, buscalo si lo necesitas.", FontTypeNames.FONTTYPE_CITIZEN
   'Invoco un banquero y guardo su index : P
   DeathMatch.BanqueroIndex = SpawnNpc(24, GetBanqueroPos, True, False)
   Exit Sub
End If
 
'Warp.
WarpUserChar winnerIndex, ToPosition.Map, ToPosition.X, ToPosition.Y, True
 
SendData SendTarget.ToAll, 0, PrepareMessageConsoleMsg("Deathmatch > Finalizado", FontTypeNames.FONTTYPE_CITIZEN)
Limpiar
 
End Sub
 
Sub AnteriorPos(ByVal UserIndex As Integer, ByRef MuertoPosition As WorldPos)
 
' @ Devuelve la posición anterior del usuario.
 
Dim loopX   As Long
 
For loopX = 1 To UBound(DeathMatch.Usuarios())
    If DeathMatch.Usuarios(loopX).UserIndex = UserIndex Then
       MuertoPosition = DeathMatch.Usuarios(loopX).LastPosition
       Exit Sub
    End If
Next loopX
 
'Posición de ulla u.u
MuertoPosition = Ullathorpe
 
End Sub
 
Function AprobarIngreso(ByVal UserIndex As Integer, ByRef MensajeError As String) As Boolean
 
' @ Checks si puede ingresar al death.
 
Dim DumpBoolean As Boolean
 
AprobarIngreso = False
 
'No hay death.
If Not DeathMatch.Activo Then
   MensajeError = "No hay deathmatch en curso."
   Exit Function
End If
 
'No hay cupos.
If Not ProximoSlot(DumpBoolean) <> 0 Then
   MensajeError = "Hay un deathmatch, pero las inscripciones están cerradas"
   Exit Function
End If
 
'Ya inscripto?
If YaInscripto(UserIndex) Then
   MensajeError = "Ya estás en el death!"
   Exit Function
End If
 
'Está muerto
If UserList(UserIndex).flags.Muerto <> 0 Then
   MensajeError = "Muerto no puedes ingresar a un deathmatch, lo siento.."
   Exit Function
End If
 
'Está preso
If UserList(UserIndex).Counters.Pena <> 0 Then
   MensajeError = "No puedes ingresar si estás preso."
   Exit Function
End If
 
AprobarIngreso = True
End Function
 
Function ProximoSlot(ByRef Sumar As Boolean) As Byte
 
' @ Posición para un usuario.
 
Dim loopX   As Long
 
Sumar = False
 
For loopX = 1 To UBound(DeathMatch.Usuarios())
    'No hay usuario.
    If Not DeathMatch.Usuarios(loopX).UserIndex <> -1 Then
       'Slot encontrado.
       ProximoSlot = loopX
       'Hay que sumar el contador?
       If DeathMatch.Ingresaron < ProximoSlot Then Sumar = True
       Exit Function
    End If
Next loopX
 
ProximoSlot = 0
 
End Function
 
Function QuedanVivos() As Byte
 
' @ Devuelve la cantidad de usuarios vivos que quedan.
 
Dim loopX   As Long
Dim Counter As Byte
 
For loopX = 1 To UBound(DeathMatch.Usuarios())
    'Mientras halla usuario.
    If DeathMatch.Usuarios(loopX).UserIndex <> -1 Then
       'Mientras esté logeado
       If UserList(DeathMatch.Usuarios(loopX).UserIndex).ConnID <> -1 Then
          'Mientras esté en el mapa de death
          If Not UserList(DeathMatch.Usuarios(loopX).UserIndex).Pos.Map <> ARENA_MAP Then
             'Sumo contador.
             Counter = Counter + 1
           End If
        End If
    End If
Next loopX
 
QuedanVivos = Counter
 
End Function
 
Function GanadorIndex() As Integer
 
' @ Busca el ganador..
 
Dim loopX   As Long
 
For loopX = 1 To UBound(DeathMatch.Usuarios())
    If DeathMatch.Usuarios(loopX).UserIndex <> -1 Then
   
       If UserList(DeathMatch.Usuarios(loopX).UserIndex).ConnID <> -1 Then
          If Not UserList(DeathMatch.Usuarios(loopX).UserIndex).Pos.Map <> ARENA_MAP Then
         
             If Not UserList(DeathMatch.Usuarios(loopX).UserIndex).flags.Muerto <> 0 Then
                GanadorIndex = DeathMatch.Usuarios(loopX).UserIndex
                Exit Function
             End If
             
           End If
        End If
       
    End If
Next loopX
 
'No hay ganador! WTF!!!
GanadorIndex = -1
 
End Function
 
Function YaInscripto(ByVal UserIndex As Integer) As Boolean
 
' @ Devuelve si ya está inscripto.
 
Dim loopX   As Long
 
For loopX = 1 To UBound(DeathMatch.Usuarios())
    If DeathMatch.Usuarios(loopX).UserIndex = UserIndex Then
       YaInscripto = True
       Exit Function
    End If
Next loopX
 
YaInscripto = False
 
End Function
 
Function GetBanqueroPos() As WorldPos
 
' @ Devuelve una posición para el banquero.
 
'No hay objeto.
If Not MapData(ARENA_MAP, BANCO_X, BANCO_Y).ObjInfo.ObjIndex <> 0 Then
   'Si no hay usuario me quedo con esta pos.
   If Not MapData(ARENA_MAP, BANCO_X, BANCO_Y).UserIndex <> 0 Then
      GetBanqueroPos.Map = ARENA_MAP
      GetBanqueroPos.X = BANCO_X
      GetBanqueroPos.Y = BANCO_Y
      Exit Function
   End If
End If
 
'Si no estaba libre el anterior tile, busco uno en un radio de 5 tiles.
Dim loopX   As Long
Dim LoopY   As Long
 
For loopX = (BANCO_X - 5) To (BANCO_X + 5)
    For LoopY = (BANCO_Y - 5) To (BANCO_Y + 5)
        With MapData(ARENA_MAP, loopX, LoopY)
             'No hay un objeto..
             If Not .ObjInfo.ObjIndex <> 0 Then
                'No hay usuario.
                If Not .UserIndex <> 0 Then
                   'Nos quedamos acá.
                   GetBanqueroPos.Map = ARENA_MAP
                   GetBanqueroPos.X = loopX
                   GetBanqueroPos.Y = LoopY
                   Exit Function
                End If
             End If
        End With
    Next LoopY
Next loopX
 
'Poco probable, pero bueno, si no hay una posición libre
'Devolvemos la posición "ORIGINAL", lo peor que puede pasar
'Es pisar un objeto : P
GetBanqueroPos.Map = ARENA_MAP
GetBanqueroPos.X = BANCO_X
GetBanqueroPos.Y = BANCO_Y
 
End Function
