macroScript XYZMeasureAdvanced
category:"My Tools"
tooltip:"高级两点测距（带3D文字标记）"
buttonText:"XYZ测距"
(
    on execute do
    (
        python.execute "
from pymxs import runtime as rt
import math

def format_number(n):
    str_num = str(n)
    if '.' in str_num:
        str_num = str_num.rstrip('0').rstrip('.')
    return str_num

def create_text_marker(p1, p2, text_content, text_size=50, offset=20):
    # 计算中间点和方向
    mid_point = (p1 + p2) / 2
    theX = rt.normalize(p2 - p1)
    view_tm = rt.viewport.getTM()
    up_vector = rt.normalize(rt.inverse(view_tm).row3)
    theY = rt.normalize(rt.cross(up_vector, theX))
    if theY.z < 0:
        theZ = rt.normalize(rt.cross(theY, theX))
    else:
        theZ = rt.normalize(rt.cross(theX, theY))
    
    # 创建3D文本
    text_node = rt.Text()
    text_node.text = text_content
    text_node.size = text_size
    text_node.wirecolor = rt.Color(255, 0, 0)  # 红色
    text_node.transform = rt.Matrix3(theX, theY, theZ, mid_point + theY * offset)
    
    # 添加挤出修改器（5mm厚度）
    extrude_mod = rt.Extrude()
    extrude_mod.amount = 5
    rt.addModifier(text_node, extrude_mod)
    return text_node

def measure_xyz_distance():
    # 启用3D捕捉
    rt.snapMode.active = True
    rt.snapMode.type = 3
    
    # 第一步：选择起点
    rt.execute('''
    try(destroyDialog firstPointPrompt)catch()
    rollout firstPointPrompt \"\" width:200 height:40
    (
        label lblMsg \"请点击第一个点\" pos:[10,10] width:180 height:20
    )
    createDialog firstPointPrompt pos:[1265,116] style:#(#style_border)
    ''')
    
    point1 = rt.pickPoint(snap=rt.Name('3D'))
    rt.execute('destroyDialog firstPointPrompt')
    if not point1:
        rt.snapMode.active = False
        return
    
    # 第二步：选择终点（带橡皮筋辅助线）
    rt.execute('''
    try(destroyDialog secondPointPrompt)catch()
    rollout secondPointPrompt \"\" width:200 height:40
    (
        label lblMsg \"请点击第二个点\" pos:[10,10] width:180 height:20
    )
    createDialog secondPointPrompt pos:[1265,116] style:#(#style_border)
    ''')
    
    point2 = rt.pickPoint(snap=rt.Name('3D'), rubberBand=point1)
    rt.execute('destroyDialog secondPointPrompt')
    if not point2:
        rt.snapMode.active = False
        return
    
    rt.snapMode.active = False
    
    # 计算距离和差值
    total_dist = round(rt.distance(point1, point2))
    delta = point2 - point1
    delta_x = round(abs(delta.x))
    delta_y = round(abs(delta.y))
    delta_z = round(abs(delta.z))
    
    # 在场景中创建3D文字标记
    create_text_marker(point1, point2, str(total_dist), text_size=50, offset=-50)
    
    # 显示结果弹窗
    msg = \"测量结果:\\n\"
    msg += \"X轴距离: \" + format_number(delta_x) + \" mm\\n\"
    msg += \"Y轴距离: \" + format_number(delta_y) + \" mm\\n\"
    msg += \"Z轴距离: \" + format_number(delta_z) + \" mm\\n\"
    msg += \"----------------\\n\"
    msg += \"总距离: \" + format_number(total_dist) + \" mm\"
    
    rt.execute('''
    try(destroyDialog resultDlg)catch()
    rollout resultDlg \"测量结果\" width:200 height:180
    (
        label lblResult \"%s\" pos:[10,10] width:200 height:100
        button btnOK \"确定\" pos:[80,140] width:60 height:30
        timer autoClose interval:3000 active:true
        on btnOK pressed do (destroyDialog resultDlg)
        on autoClose tick do (destroyDialog resultDlg)
    )
    createDialog resultDlg pos:[1265,116] style:#(#style_border)
    ''' % msg)

# 执行测量
measure_xyz_distance()
"
    )
)