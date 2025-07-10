macroScript XYZMeasureAdvanced
category:"My Tools"
tooltip:"高级两点测距（带3D文字标记和方向区分）"
buttonText:"XYZ测距(方向)"
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

def create_text_marker(p1, p2, text_content, text_size=50, pos_offset=20, neg_offset=-20):
    # 计算中间点和方向
    mid_point = (p1 + p2) / 2
    theX = rt.normalize(p2 - p1)
    
    # 检测各轴方向 - 翻转Y轴和Z轴的正负判断
    is_x_positive = theX.x > 0
    is_y_positive = theX.y < 0  # 翻转Y轴正负判断
    is_z_positive = theX.z < 0  # 翻转Z轴正负判断
    
    # 判断哪个轴是主要方向（绝对值最大的分量）
    abs_x = abs(theX.x)
    abs_y = abs(theX.y)
    abs_z = abs(theX.z)
    
    main_axis = 'x'
    if abs_y > abs_x and abs_y > abs_z:
        main_axis = 'y'
    elif abs_z > abs_x and abs_z > abs_y:
        main_axis = 'z'
    
    view_tm = rt.viewport.getTM()
    up_vector = rt.normalize(rt.inverse(view_tm).row3)
    theY = rt.normalize(rt.cross(up_vector, theX))
    if theY.z < 0:
        theZ = rt.normalize(rt.cross(theY, theX))
    else:
        theZ = rt.normalize(rt.cross(theX, theY))
    
    # 根据主要方向和正负方向选择偏移量
    if main_axis == 'x':
        use_offset = pos_offset if is_x_positive else neg_offset
    elif main_axis == 'y':
        use_offset = pos_offset if is_y_positive else neg_offset
    else: # z轴
        use_offset = pos_offset if is_z_positive else neg_offset
    
    # 创建3D文本
    text_node = rt.Text()
    text_node.text = text_content
    text_node.size = text_size
    text_node.wirecolor = rt.Color(255, 0, 0)  # 红色
    
    # 根据不同轴的主要方向调整文本朝向 - 修改Y轴和Z轴的文本朝向逻辑
    if main_axis == 'y':
        # 根据Y轴方向决定如何翻转文本
        if is_y_positive:  # Y轴正方向（实际为原脚本的负方向）
            text_node.transform = rt.Matrix3(theX, theY, theZ, mid_point + theY * use_offset)
        else:  # Y轴负方向（实际为原脚本的正方向）
            text_node.transform = rt.Matrix3(-theX, -theY, -theZ, mid_point + theY * use_offset)
    elif main_axis == 'x' and not is_x_positive:
        # X轴负方向：翻转X和Y轴
        text_node.transform = rt.Matrix3(-theX, -theY, theZ, mid_point + theY * use_offset)
    elif main_axis == 'z' and not is_z_positive:  # 修改Z轴条件判断
        # Z轴负方向（实际为原脚本的正方向）：翻转X和Y轴
        text_node.transform = rt.Matrix3(-theX, -theY, theZ, mid_point + theY * use_offset)
    else:
        # 其他情况：正常显示
        text_node.transform = rt.Matrix3(theX, theY, theZ, mid_point + theY * use_offset)
    
    # 添加挤出修改器（5mm厚度）
    extrude_mod = rt.Extrude()
    extrude_mod.amount = 5
    rt.addModifier(text_node, extrude_mod)
    return text_node

def measure_xyz_distance():
    # 启用3D捕捉
    rt.snapMode.active = True
    rt.snapMode.type = 3
    
    # 初始状态，需要选择第一个点
    need_first_point = True
    point1 = None
    
    while True:
        if need_first_point:
            # 第一步：选择起点
            rt.execute('''
            try(destroyDialog firstPointPrompt)catch()
            rollout firstPointPrompt \"\" width:200 height:40
            (
                label lblMsg \"请点击第一个点 (ESC或右键取消)\" pos:[10,10] width:180 height:20
            )
            createDialog firstPointPrompt pos:[1265,116] style:#(#style_border)
            ''')
            
            try:
                point1 = rt.pickPoint(snap=rt.Name('3D'))
            except:
                rt.snapMode.active = False
                rt.execute('destroyDialog firstPointPrompt')
                break
            
            rt.execute('destroyDialog firstPointPrompt')
            if not point1:
                rt.snapMode.active = False
                break
            
            need_first_point = False
        
        # 第二步：选择终点（带橡皮筋辅助线）
        rt.execute('''
        try(destroyDialog secondPointPrompt)catch()
        rollout secondPointPrompt \"\" width:200 height:40
        (
            label lblMsg \"请点击第二个点 (ESC或右键取消)\" pos:[10,10] width:180 height:20
        )
        createDialog secondPointPrompt pos:[1265,116] style:#(#style_border)
        ''')
        
        try:
            point2 = rt.pickPoint(snap=rt.Name('3D'), rubberBand=point1)
        except:
            rt.snapMode.active = False
            rt.execute('destroyDialog secondPointPrompt')
            break
        
        rt.execute('destroyDialog secondPointPrompt')
        if not point2:
            rt.snapMode.active = False
            break
        
        # 计算距离和差值
        total_dist = round(rt.distance(point1, point2))
        delta = point2 - point1
        
        # 分别计算各轴的正向和负向偏移 - 翻转Y轴和Z轴的正负计算
        delta_x = delta.x
        delta_y = -delta.y  # 翻转Y轴方向
        delta_z = -delta.z  # 翻转Z轴方向
        
        x_positive = delta_x if delta_x >= 0 else 0
        x_negative = abs(delta_x) if delta_x < 0 else 0
        y_positive = delta_y if delta_y >= 0 else 0
        y_negative = abs(delta_y) if delta_y < 0 else 0
        z_positive = delta_z if delta_z >= 0 else 0
        z_negative = abs(delta_z) if delta_z < 0 else 0
        
        # 在场景中创建3D文字标记（总距离）
        create_text_marker(point1, point2, str(total_dist), text_size=50, pos_offset=-40, neg_offset=-20)
        
        # 创建各轴偏移的文字标记（可选，如需显示可取消注释）
        # create_text_marker(point1, p2, f\"X:+{x_positive}/-{x_negative}\", text_size=30, pos_offset=10, neg_offset=10)
        
        # 显示结果弹窗（包含方向信息）
        msg = \"测量结果:\\n\"
        msg += \"X轴偏移: +\" + format_number(x_positive) + \" / -\" + format_number(x_negative) + \" mm\\n\"
        msg += \"Y轴偏移: +\" + format_number(y_positive) + \" / -\" + format_number(y_negative) + \" mm\\n\"
        msg += \"Z轴偏移: +\" + format_number(z_positive) + \" / -\" + format_number(z_negative) + \" mm\\n\"
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
        
        # 将当前终点设为下一轮的起点
        point1 = point2
        need_first_point = False

# 执行测量
try:
    measure_xyz_distance()
except:
    pass
"
    )
)