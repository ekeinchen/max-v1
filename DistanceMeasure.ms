macroScript MeasureTwoPoints
category:"My Tools"
tooltip:"两点测距(带橡皮筋辅助线)"
(
    on execute do
    (
        python.execute "
from pymxs import runtime as rt
import time

def show_click_to_close_message(message):
    maxscript = '''try(destroyDialog tempPrompt)catch()
    rollout tempPrompt \"\" width:200 height:60
    (
        label lblMsg \"%s\" pos:[10,10] width:180 height:40
    )
    createDialog tempPrompt pos:[1265,116] style:#(#style_border)''' % message
    rt.execute(maxscript)

def measure_two_points():
    rt.snapMode.active = True
    rt.snapMode.type = 3
    
    show_click_to_close_message(\"请点击第一个点\")
    point1 = rt.pickPoint(snap=rt.Name('3D'))
    rt.execute(\"try(destroyDialog tempPrompt)catch()\")
    if not point1:
        rt.snapMode.active = False
        return

    show_click_to_close_message(\"请点击第二个点\") 
    point2 = rt.pickPoint(snap=rt.Name('3D'), rubberBand=point1)  # 添加橡皮筋辅助线
    rt.execute(\"try(destroyDialog tempPrompt)catch()\")
    if not point2:
        rt.snapMode.active = False
        return

    rt.snapMode.active = False
    
    dist = rt.distance(point1, point2)
    delta = point2 - point1
    
    msg = \"距离: %.2f\\nX: %.2f\\nY: %.2f\\nZ: %.2f\" % (dist, delta.x, delta.y, delta.z)
    
    maxscript = '''try(destroyDialog resultDlg)catch()
    rollout resultDlg \"\" width:200 height:140
    (
        label lblResult \"%s\" pos:[10,10] width:180 height:80
        button btnOK \"确定\" pos:[70,100] width:60 height:30
        timer autoClose interval:4000 active:true
        
        on btnOK pressed do (destroyDialog resultDlg)
        on autoClose tick do (destroyDialog resultDlg)
    )
    createDialog resultDlg pos:[1265,116] style:#(#style_border)''' % msg
    rt.execute(maxscript)

measure_two_points()
"
    )
)