// Coriander Player v1.5.2 自解压升级程序
// 编译: csc.exe /target:winexe /win32icon:app_icon.ico /resource:coriander_player.zip /out:CorianderPlayer_Upgrade_v1.5.2.exe sfx_installer.cs

using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;

class SfxInstaller
{
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool AttachConsole(uint dwProcessId);
    const uint ATTACH_PARENT_PROCESS = 0xFFFFFFFF;

    static void Main()
    {
        // 尝试附加到父进程控制台（双击运行时无控制台，不报错）
        try { AttachConsole(ATTACH_PARENT_PROCESS); } catch { }

        Console.OutputEncoding = Encoding.UTF8;
        Console.WriteLine("");
        Console.WriteLine("============================================");
        Console.WriteLine("  Coriander Player v1.5.2 升级程序");
        Console.WriteLine("============================================");
        Console.WriteLine("");

        try
        {
            // 查找嵌入的 ZIP 资源
            var asm = Assembly.GetExecutingAssembly();
            string resourceName = null;
            foreach (var name in asm.GetManifestResourceNames())
            {
                if (name.EndsWith(".zip", StringComparison.OrdinalIgnoreCase))
                {
                    resourceName = name;
                    break;
                }
            }

            if (resourceName == null)
            {
                Console.WriteLine("[错误] 未找到升级数据包。");
                Pause();
                return;
            }

            // 解压到临时目录
            var tempDir = Path.Combine(Path.GetTempPath(), "coriander_upgrade_" + Guid.NewGuid().ToString("N").Substring(0, 8));
            Directory.CreateDirectory(tempDir);

            Console.WriteLine("[信息] 正在解压升级包...");
            using (var stream = asm.GetManifestResourceStream(resourceName))
            using (var archive = new ZipArchive(stream, ZipArchiveMode.Read))
            {
                foreach (var entry in archive.Entries)
                {
                    var destPath = Path.Combine(tempDir, entry.FullName);
                    var destDir = Path.GetDirectoryName(destPath);
                    if (!string.IsNullOrEmpty(destDir))
                        Directory.CreateDirectory(destDir);
                    if (!string.IsNullOrEmpty(entry.Name))
                        entry.ExtractToFile(destPath, overwrite: true);
                }
            }
            Console.WriteLine("[信息] 解压完成。");

            // 查找安装目录
            string installDir = FindInstallDir();
            if (installDir == null)
            {
                Console.Write("[询问] 未找到 Coriander Player 安装目录，请输入路径: ");
                var input = Console.ReadLine();
                installDir = input != null ? input.Trim() : null;
                if (string.IsNullOrEmpty(installDir) || !Directory.Exists(installDir))
                {
                    Console.WriteLine("[错误] 路径无效。");
                    Pause();
                    return;
                }
            }

            Console.WriteLine("[信息] 安装目录: " + installDir);

            // 关闭旧进程
            Console.WriteLine("[操作] 正在关闭旧版本...");
            KillProcess("coriander_player");
            KillProcess("desktop_lyric");
            System.Threading.Thread.Sleep(1500);

            // 复制文件
            Console.WriteLine("[操作] 正在复制新版本文件...");
            CopyDirectory(tempDir, installDir);

            // 清理临时目录
            try { Directory.Delete(tempDir, recursive: true); } catch { }

            Console.WriteLine("");
            Console.WriteLine("========== 升级完成！==========");
            Console.WriteLine("");

            // 启动新版本
            var exePath = Path.Combine(installDir, "coriander_player.exe");
            if (File.Exists(exePath))
            {
                Console.WriteLine("[信息] 正在启动 Coriander Player v1.5.2...");
                Process.Start(exePath);
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine("[错误] " + ex.Message);
            Pause();
        }
    }

    static string FindInstallDir()
    {
        try
        {
            // 从运行中的进程查找
            foreach (var proc in Process.GetProcessesByName("coriander_player"))
            {
                try
                {
                    var dir = Path.GetDirectoryName(proc.MainModule.FileName);
                    if (dir != null && Directory.Exists(dir))
                        return dir;
                }
                catch { }
            }
        }
        catch { }

        // 常见安装位置
        string[] commonPaths = {
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "coriander_player"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "coriander_player"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "coriander_player"),
            @"C:\Program Files\coriander_player",
            @"C:\Program Files (x86)\coriander_player",
        };
        foreach (var p in commonPaths)
        {
            if (File.Exists(Path.Combine(p, "coriander_player.exe")))
                return p;
        }
        return null;
    }

    static void KillProcess(string name)
    {
        try
        {
            foreach (var proc in Process.GetProcessesByName(name))
            {
                proc.Kill();
                proc.WaitForExit(3000);
            }
        }
        catch { }
    }

    static void CopyDirectory(string src, string dst)
    {
        // 复制根目录文件
        foreach (var file in Directory.GetFiles(src))
        {
            var name = Path.GetFileName(file);
            if (name.Equals("sfx_installer.exe", StringComparison.OrdinalIgnoreCase))
                continue;
            var dest = Path.Combine(dst, name);
            try { File.Copy(file, dest, overwrite: true); } catch { }
        }

        // 复制子目录
        foreach (var dir in Directory.GetDirectories(src))
        {
            var dirName = Path.GetFileName(dir);
            var destDir = Path.Combine(dst, dirName);
            Directory.CreateDirectory(destDir);
            CopyDirectory(dir, destDir);
        }
    }

    static void Pause()
    {
        Console.WriteLine("");
        Console.Write("按任意键退出...");
        try { Console.ReadKey(true); } catch { }
    }
}
