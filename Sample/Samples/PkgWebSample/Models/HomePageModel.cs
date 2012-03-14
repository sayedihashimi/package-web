namespace PkgWebSample.Models {
    using System;
    using System.Collections.Generic;
    using System.Linq;
    using System.Web;

    public class HomePageModel {
        public HomePageModel() {
            this.AppSettings = new Dictionary<string, string>();
            this.ConnectionStrings = new Dictionary<string, string>();
        }

        public Dictionary<string, string> AppSettings { get; set; }
        public Dictionary<string, string> ConnectionStrings { get; set; }
    }
}