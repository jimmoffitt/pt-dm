pt_dm
=====

**Download manager for Gnip Historical PowerTrack.  Written in Ruby for Windows 7, MacOS and Linux.**

This application automates the downloading of Historical PowerTrack data files.  The application is made up of two executables: dm_ui.exe and dm_process.exe.  The dm_ui executable provides the user interface for entering account  information, job details, and download options.  The user interface also enables monitoring of the download progress, as well as launches the dm_process executable. The dm_process executable automates the file downloading. The dm_process can also be used with a headless script, dm_script.rb.  

Setting up application:
+ Copy dm_process.exe and dm_ui.exe to a folder.
+ Run dm_ui.exe and enter your configuration:
  + Account name, username and password.
  + Output folder (defaults to ./output and is automatically created).
  + The configuration file is automatically created if needed.

Downloading files:
+ Click the "Download Data" button.  

**The Joys of Tk and Threading**

[Saga of threading and landing with two separate processes?]

**Cross-process messaging**

The UI and worker objects/apps needed to communicate with each other.  The UI needed to launch the download process. The progress of the download process needed to be displayed on the UI.  If the UI needed to pause the download, the download process ideally could be notified, gracefully finish with the current file before stopping.

Since a design goal was to develop on the MacOS and deploy on Windows, a simple cross-process communication mechanism was needed.  As a first step it was designed to communicate via a simple YAML status file.  Both applications reference a common status class with methods for reading and writing the status file.


**SSL certificate issues with Ruby on Windows**

Some useful links about the Ruby/net::https/SSL issue:
http://blog.kabisa.nl/2009/12/04/ruby-and-ssl-certificate-validation/
http://notetoself.vrensk.com/2008/09/verified-https-in-ruby/

If you are getting SSL certificate errors, try removing the "cacert.pem" in the local directory.
If that file is not found, this app will go out and create a fresh file from http://curl.haxx.se/ca/cacert.pem.


**Creating a Ruby executable on Windows**

This Ruby app is deployed on Windows using the Ocra gem:
http://rubyonwindows.blogspot.com/2009/05/ocra-one-click-ruby-application-builder.html

If you want to make code changes, you can re-create the Windows executable with these commands:
* \pt_dm\ocra dm_process.rb --windows
* \pt_dm\ocra dm_ui.rb --windows --no-autoload
