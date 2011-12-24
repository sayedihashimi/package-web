namespace Sedodream.Powershell.Publish {
    using System;
    using System.Collections.Generic;
    using System.Linq;
    using System.Text;

    public interface ITransformer {
        void Transform(string assemblyPath, string source, string transform, string destination);
    }
}
