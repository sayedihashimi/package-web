namespace Sedodream.Powershell.Publish {
    using System;
    using System.IO;
    using System.Reflection;
    using Sedodream.Powershell.Publish.Exceptions;
    using Sedodream.Powershell.Publish.Properties;

    public class Transformer : ITransformer {

        public void Transform(string source, string transform, string destination) {
            // look for the assembly in the default location
            throw new NotImplementedException();
        }
        public void Transform(string assemblyPath, string source, string transform, string destination) {
            if (string.IsNullOrWhiteSpace(assemblyPath)) { throw new ArgumentNullException("assemblyPath"); }
            if (string.IsNullOrWhiteSpace(source)) { throw new ArgumentNullException("source"); }
            if (string.IsNullOrWhiteSpace(transform)) { throw new ArgumentNullException("transform"); }
            if (string.IsNullOrWhiteSpace(destination)) { throw new ArgumentNullException("destination"); }

            if (!File.Exists(source)) {
                throw new FileNotFoundException("File to transform not found", source);
            }
            if (!File.Exists(transform)) {
                throw new FileNotFoundException("Transform file not found", transform);
            }

            // get the path to the assmebly which has the TransformXml task inside of it
            // Settings.Default.InstallPath; => MSBuild\SlowCheetah\v1\
            // Settings.Default.TransformAssemblyPath; => SlowCheetah.Tasks.dll
            // System.Environment.ExpandEnvironmentVariables(Consts.PublicFolder)

            //string assemblyPath = Path.Combine(
            //    this.InstallRoot,
            //    Settings.Default.TransformAssemblyPath);



            if (!File.Exists(assemblyPath)) {
                throw new FileNotFoundException("Transfrom assembly not found", assemblyPath);
            }

            // load the assembly
            Assembly assembly = Assembly.LoadFile(assemblyPath);
            // find the class
            Type type = assembly.GetType(Settings.Default.TransformXmlTaskName, true, true);

            // create a new instance of it
            dynamic transformTask = Activator.CreateInstance(type);
            // set the properties on it
            transformTask.BuildEngine = new MockBuildEngine();
            transformTask.Source = source;
            transformTask.Transform = transform;
            transformTask.Destination = destination;

            bool succeeded = transformTask.Execute();

            if (!succeeded) {
                string message = string.Format("There was an error processing the transformation.");
                throw new TransformFailedException(message);
            }
        }
    }
}
