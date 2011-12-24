namespace Sedodream.Powershell.Publish {
    using System;
    using System.Collections.Generic;
    using System.Text;
    using System.Management.Automation;

    [Cmdlet("Extract", "Zip")]
    public class ExtractZip : Cmdlet {

        #region Powershell properties
        [Parameter(Mandatory=true)]
        public string Zipfile { get; set; }

        [Parameter(Mandatory=true)]
        public string OutputFolder { get; set; }
        #endregion

        protected override void ProcessRecord() {
            base.ProcessRecord();

            System.Console.WriteLine("ProcessRecord called");
        }

    }
}
