// Coriander Player v1.5.2 自解压升级程序
using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;

class SfxInstaller
{
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern int MessageBox(IntPtr hWnd, string text, string caption, uint type);
    const uint MB_OK = 0x0;
    const uint MB_ICONERROR = 0x10;
    const uint MB_ICONINFO = 0x40;

    static void Main()
    {
        try
        {
            Console.OutputEncoding = Encoding.UTF8;
            Console.Title = "Coriander Player v1.5.2 升级";

            Console.WriteLine("============================================");
            Console.WriteLine("  Coriander Player v1.5.2 升级程序");
            Console.WriteLine("============================================");
            Console.WriteLine();

            // 查找嵌入的 ZIP 资源
            var asm = Assembly.GetExecutingAssembly();
            string resourceName = null;
            foreach (var name in asm.GetManifestResourceNames())
            {
                if (name.EndsWith(".zip", StringComparison.OrdinalIgnoreCase))
                { resourceName = name; break; }
            }
            if (resourceName == null)
            { Fatal("未找到升级数据包。"); return; }

            // 解压到临时目录
            var tempDir = Path.Combine(
                Path.GetTempPath(),
                "coriander_upgrade_" + Guid.NewGuid().ToString("N").Substring(0, 8));
            Directory.CreateDirectory(tempDir);

            Console.WriteLine("正在解压升级包...");
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
            Console.WriteLine("解压完成。");

            // 查找安装目录
            string installDir = FindInstallDir();
            if (installDir == null)
            {
                Console.Write("未找到安装目录，请输入路径: ");
                var input = Console.ReadLine();
                installDir = input != null ? input.Trim() : null;
                if (string.IsNullOrEmpty(installDir) || !Directory.Exists(installDir))
                { Fatal("路径无效。"); return; }
            }
            Console.WriteLine("安装目录: " + installDir);

            // 关闭旧进程
            Console.WriteLine("正在关闭旧版本...");
            KillProcess("coriander_player");
            KillProcess("desktop_lyric");
            System.Threading.Thread.Sleep(1500);

            // 复制文件
            Console.WriteLine("正在复制新版本文件...");
            CopyDirectory(tempDir, installDir);

            // 清理
            try { Directory.Delete(tempDir, recursive: true); } catch { }

            Console.WriteLine();
            Console.WriteLine("========== 升级完成！==========");

            var exePath = Path.Combine(installDir, "coriander_player.exe");
            if (File.Exists(exePath))
            {
                Console.WriteLine("正在启动 Coriander Player v1.5.2...");
                Process.Start(exePath);
            }

            PauseExit("按任意键退出...");
        }
        catch (Exception ex)
        {
            Fatal("升级失败: " + ex.Message);
        }
    }

    static void Fatal(string msg)
    {
        Console.WriteLine();
        Console.WriteLine("[错误] " + msg);
        try { MessageBox(IntPtr.Zero, msg, "Coriander Player 升级失败", MB_OK | MB_ICONERROR); } catch { }
        PauseExit("按任意键退出...");
    }

    static void PauseExit(string prompt)
    {
        Console.WriteLine();
        Console.Write(prompt);
        try { Console.ReadKey(true); } catch { }
    }

    static string FindInstallDir()
    {
        try
        {
            foreach (var proc in Process.GetProcessesByName("coriander_player"))
            {
                try
                {
                    var dir = Path.GetDirectoryName(proc.MainModule.FileName);
                    if (dir != null && Directory.Exists(dir)) return dir;
                }
                catch { }
            }
        }
        catch { }

        string[] paths =
        {
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "coriander_player"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "coriander_player"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "coriander_player"),
            @"C:\Program Files\coriander_player",
        };
        foreach (var p in paths)
        {
            if (File.Exists(Path.Combine(p, "coriander_player.exe"))) return p;
        }
        return null;
    }

    static void KillProcess(string name)
    {
        try
        {
            foreach (var proc in Process.GetProcessesByName(name))
            { proc.Kill(); proc.WaitForExit(3000); }
        }
        catch { }
    }

    static void CopyDirectory(string src, string dst)
    {
        foreach (var file in Directory.GetFiles(src))
        {
            var name = Path.GetFileName(file);
            if (name.IndexOf("sfx_installer", StringComparison.OrdinalIgnoreCase) >= 0) continue;
            if (name.IndexOf("CorianderPlayer_Upgrade", StringComparison.OrdinalIgnoreCase) >= 0) continue;
            try { File.Copy(file, Path.Combine(dst, name), overwrite: true); } catch { }
        }
        foreach (var dir in Directory.GetDirectories(src))
        {
            var dirName = Path.GetFileName(dir);
            var destDir = Path.Combine(dst, dirName);
            Directory.CreateDirectory(destDir);
            CopyDirectory(dir, destDir);
        }
    }
}
