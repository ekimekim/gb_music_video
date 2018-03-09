using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace animparse.Frames.Aseprite
{
    public class AseAnimation
    {
        public Dictionary<string, AseFrame> frames;

        public static AseAnimation FromFile(string path)
        {
            var json = File.ReadAllText(path);
            var anim = JsonConvert.DeserializeObject<AseAnimation>(json);
            return anim;
        }
    }
}
