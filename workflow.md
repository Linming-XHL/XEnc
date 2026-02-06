加密流程：
graph TD
    A[用户选择需要加密的文件] --> B{判断是否为多个文件?}
    
    B -- 是 --> C[进行ZIP压缩<br/>密码: encryption]
    B -- 否 --> D[进入加密流程]
    
    C --> D
    
    subgraph D [加密流程]
        D1[获取待加密文件] --> D2[使用RAR格式压缩<br/>密码: fox]
        D2 --> D3[在文件头部添加8个F]
        D3 --> D4[修改后缀名为.xenc]
        D4 --> D5[模拟Windows指令<br/>copy /b 原文件.xenc + 混淆文件.mp4 输出文件.mp4]
        D5 --> E[输出最终加密文件: 输出文件.mp4]
    end



解密流程：
graph TD
    A[获取加密的.mp4文件] --> B[分离出.xenc文件<br/>反向执行copy命令]
    B --> C[去除文件头部的8个F]
    C --> D[将.xenc重命名为.rar文件]
    D --> E[使用RAR密码: fox 解压]
    E --> F{是否为ZIP压缩包?}
    
    F -- 是 --> G[使用ZIP密码: encryption 解压]
    F -- 否 --> H[得到原始文件]
    
    G --> H