#if HAXEUI_CS_HEADLESS
using Avalonia.Headless;
using Avalonia.Threading;

namespace HaxeUICs
{
    /// <summary>
    /// Drives the headless host for tests: runs queued work and render ticks, and (in later tasks)
    /// injects input and captures frames. Haxe reaches it through haxe.ui.backend.cs.TestDriver.
    /// </summary>
    public static class HeadlessDriver
    {
        public static void Pump(int frames)
        {
            for (var i = 0; i < frames; i++)
            {
                Dispatcher.UIThread.RunJobs();
                AvaloniaHeadlessPlatform.ForceRenderTimerTick();
                Dispatcher.UIThread.RunJobs();
            }
        }
    }
}
#endif
