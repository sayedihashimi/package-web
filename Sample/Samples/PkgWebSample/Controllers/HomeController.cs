namespace PkgWebSample.Controllers {
    using System.Configuration;
    using System.Web.Mvc;
    using PkgWebSample.Models;

    public class HomeController : Controller {
        public ActionResult Index() {
            
            // get app settings
            HomePageModel hpm = new HomePageModel();

            foreach (var key in ConfigurationManager.AppSettings.AllKeys) {
                hpm.AppSettings[key] = ConfigurationManager.AppSettings[key];
            }

            foreach (ConnectionStringSettings conString in ConfigurationManager.ConnectionStrings) {
                hpm.ConnectionStrings[conString.Name] = conString.ConnectionString;
            }

            return View(hpm);
        }

    }
}
