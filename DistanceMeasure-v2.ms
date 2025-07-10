macroScript MeasureTwoPoints
category:"My Tools"
tooltip:"两点测距(带橡皮筋辅助线)"
(
    -- 格式化数字显示（保留个位数）
    fn formatNumber n = (
        local rounded = (n + 0.5) as integer  -- 四舍五入到整数
        return rounded as string
    )

    -- 智能计算文本偏移方向（动态适应测量方向）
    fn getOffsetDirection p1 p2 viewForward viewUp = (
        local dir = normalize (p2 - p1)
        local viewRight = normalize (cross viewForward viewUp)
        
        -- 优先使用测量线与视图方向的叉积作为偏移方向
        local offsetDir = normalize (cross dir viewForward)
        
        -- 如果叉积结果太小(接近平行)，使用备选方向
        if (length offsetDir) < 0.1 do (
            offsetDir = normalize (cross dir viewUp)
        )
        
        return offsetDir
    )

    -- 创建3D测量标记（面向摄像机+动态偏移）
    fn createMarker p1 p2 txt = (
        -- 获取当前视图信息
        local viewTM = viewport.getTM()
        local viewForward = normalize ((inverse viewTM).row3)  -- 视图前方向量
        local viewUp = normalize ((inverse viewTM).row2)       -- 视图上方向量
        local viewRight = normalize (cross viewUp viewForward) -- 视图右方向量
        
        -- 定义四个方向的偏移量参数
        local offsetRight = 30  -- 右方向偏移量
        local offsetLeft = 10   -- 左方向偏移量
        local offsetUp = 40     -- 上方向偏移量
        local offsetDown = 40   -- 下方向偏移量
        
        -- 计算中点位置
        local midPoint = (p1 + p2) / 2
        
        -- 计算智能偏移
        local offsetDir = getOffsetDirection p1 p2 viewForward viewUp
        
        -- 判断主要方向并选择对应的偏移量
        local mainDir = normalize (p2 - p1)
        local rightDot = dot mainDir viewRight
        local upDot = dot mainDir viewUp
        
        -- 根据方向选择合适的偏移量
        local finalOffsetDist = 
            if rightDot > 0.5 then offsetRight       -- 主要向右
            else if rightDot < -0.5 then offsetLeft  -- 主要向左
            else if upDot > 0.5 then offsetUp        -- 主要向上
            else if upDot < -0.5 then offsetDown     -- 主要向下
            else (offsetRight + offsetLeft + offsetUp + offsetDown) / 4  -- 其他情况取平均值
        
        -- 应用原始的距离因子（使垂直于视图的线显示更大的偏移）
        finalOffsetDist = finalOffsetDist * (1 + (1 - abs (dot viewForward mainDir)) / 2)
        
        -- 创建文本对象
        local marker = text size:50 text:txt wirecolor:red
        marker.pos = midPoint + offsetDir * finalOffsetDist
        
        -- 设置文本变换矩阵（始终面向视图）
        marker.transform = matrix3 viewRight viewUp viewForward marker.pos
        
        -- 添加厚度
        addModifier marker (Extrude amount:5)
        return marker
    )

    -- 显示测量结果对话框
    fn showResult deltaX deltaY deltaZ totalDist = (
        local msg = "测量结果:\n"
        msg += "X轴距离: " + (formatNumber deltaX) + " mm\n"
        msg += "Y轴距离: " + (formatNumber deltaY) + " mm\n"
        msg += "Z轴距离: " + (formatNumber deltaZ) + " mm\n"
        msg += "----------------\n"
        msg += "总距离: " + (formatNumber totalDist) + " mm"
        
        try(destroyDialog resultDlg)catch()
        rollout resultDlg "测量结果" width:200 height:180
        (
            label lblResult "" pos:[10,10] width:180 height:100
            button btnOK "确定" pos:[80,140] width:60 height:30
            timer autoClose interval:3000 active:true
            on btnOK pressed do (destroyDialog resultDlg)
            on autoClose tick do (destroyDialog resultDlg)
        )
        createDialog resultDlg pos:[1265,116] style:#(#style_border)
        resultDlg.lblResult.caption = msg
    )

    -- 主测量流程
    fn runMeasurement = (
        -- 设置捕捉模式
        snapMode.active = true
        snapMode.type = #3D
        
        -- 第一步：获取起点
        try(destroyDialog firstPointPrompt)catch()
        rollout firstPointPrompt "" width:200 height:40
        (
            label lblMsg "请点击第一个点 (ESC或右键取消)" pos:[10,10] width:180 height:20
        )
        createDialog firstPointPrompt pos:[1265,116] style:#(#style_border)
        
        local p1
        try ( 
            p1 = pickPoint snap:#3D 
            if p1 == undefined do return undefined 
        ) catch ( 
            snapMode.active = false
            destroyDialog firstPointPrompt
            return undefined 
        )
        destroyDialog firstPointPrompt
        
        -- 连续测量模式
        while true do (
            -- 确保捕捉模式正确
            snapMode.active = true
            snapMode.type = #3D
            
            -- 第二步：获取终点
            try(destroyDialog secondPointPrompt)catch()
            rollout secondPointPrompt "" width:200 height:40
            (
                label lblMsg "请点击第二个点 (ESC或右键取消)" pos:[10,10] width:180 height:20
            )
            createDialog secondPointPrompt pos:[1265,116] style:#(#style_border)
            
            local p2
            try ( 
                p2 = pickPoint snap:#3D rubberBand:p1 
                if p2 == undefined do exit 
            ) catch ( 
                snapMode.active = false
                destroyDialog secondPointPrompt
                exit 
            )
            destroyDialog secondPointPrompt
            
            -- 计算距离
            local dist = distance p1 p2
            local delta = p2 - p1
            local deltaX = abs delta.x
            local deltaY = abs delta.y
            local deltaZ = abs delta.z
            
            -- 创建标记
            createMarker (copy p1) (copy p2) (formatNumber dist)
            
            -- 显示结果
            showResult deltaX deltaY deltaZ dist
            
            -- 将终点设为新的起点
            p1 = copy p2
            
            -- 添加短暂延迟，避免操作冲突
            sleep 0.1
        )
        
        snapMode.active = false
    )

    -- 执行入口
    on execute do (
        try ( 
            runMeasurement() 
        ) 
        catch ( 
            try(destroyDialog firstPointPrompt)catch()
            try(destroyDialog secondPointPrompt)catch()
            -- 移除了错误提示弹窗
        )
    )
)    