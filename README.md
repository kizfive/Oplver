#Oplver

一个基于flutter的Openlist文件浏览器,基于Openlist的Webdav服务,所以理论上也可以用于其他支持Webdav服务的项目.  
这个App是出于个人目的才开始写的,所以虽然理论上支持多平台,但是软件本身只在安卓设备上测试过,故只提供安卓安装包.

## 许可证

本项目采用 GPLv3 许可证开源。

### 第三方库许可证

本软件使用了以下关键依赖：
- **fvp** (LGPL-2.1): 视频播放引擎，用户可通过修改 pubspec.yaml 自行替换版本

详细的第三方库许可信息请查看应用内"关于"页面或 NOTICE 文件。

### LGPL 合规说明

fvp 库采用 LGPL-2.1 许可证，符合以下要求：
1. 本软件源代码公开
2. 用户可通过修改 `pubspec.yaml` 替换 fvp 版本：
   ```yaml
   dependencies:
     fvp: ^0.35.2  # 可改为其他兼容版本
   ```
3. 完整的 LGPL-2.1 许可证文本见 licenses/LGPL-2.1.txt

