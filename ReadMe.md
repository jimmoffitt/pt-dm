pt-dm == Historical PowerTrack Data Manager
=====

**Data manager for Gnip Historical PowerTrack.  Written in Ruby for Windows 7, MacOS and Linux.**

This application automates the downloading of Historical PowerTrack data files. Once those files are downloaded, this tool can convert tweets from JSON to CSV and consolidate 10-minute files into hourly or daily data files. 

So, there are three main processes managed here, with corresponding classes encapsulating this functionality:

    * HTTP Downloading and uncompressing Historical PowerTrack 10-minute JSON flatfiles.
    * Converting JSON tweet payloads to CSV.  Requires a 'template tweet' to select fields for conversion.
    * Consolidating 10-minute files into hourly or daily files.
        * Works with either JSON and CSV formats.
        * Can also produce a single CSV file, but tool needs to gatekeep requests that would produce silly-sized files.
        * Designed to be flexible.  Can consolidate hourly files into daily files for example.
        

User-interface (UI) was implemented with Ruby Tk window toolkit. Tk was selected for this prototype because it is native to the Ruby package installed on MacOS and Windows.  Since separating UI details from the data and file processing was a fundamental goal, it was assumed the UI details could be swapped out for others implemented in native Windows tool or deployed on Rails.
      
     [User Interface on MacOS](./screenshots/Gnip_Historical_PowerTrack_Data_Manager.png "MacOS")
        
     [User Interface on Windows 7](./screenshots/Gnip_Historical_PowerTrack_Data_Manager.png "Win7")

        

The application is made up of two executables: dm_ui.exe and dm_process.exe.  The dm_ui executable provides the user interface for entering account information, job details, and download, conversion, and consolidation options.  The user interface also enables monitoring of the download progress, as well as launches the dm_process executable. The dm_process executable automates and manages file downloading, data format conversion, and file consolidation. The dm_process can also be used with a headless script, dm_script.rb.  

Setting up application on Windows:
+ Copy dm_process.exe and dm_ui.exe to a folder.
+ Run dm_ui.exe and enter your configuration:
  + Account name, username and password.
  + Job Data URL (https://historical.gnip.com:443/../results.json) or just the Job UUID.
  + Output folder (defaults to ./output and is automatically created).
  + The configuration file is automatically created if needed.

Setting up application on MacOS/Linux:
+ Application runs on top of Ruby interpreter.
+ dm_ui.rb is the "main" file to execute.  

Downloading files:
+ Click the "Download Data" button.  

***Development notes***


**The Joys of Tk and Threading**

[Saga of threading and landing with two separate processes?]

**Cross-process messaging**

The UI and worker objects/apps needed to communicate with each other.  The UI needed to launch the download process. The progress of the download process needed to be displayed on the UI.  If the UI needed to pause the download, the download process ideally could be notified, gracefully finish with the current file before stopping.

Since a design goal was to develop on the MacOS and deploy on Windows, a simple cross-process communication mechanism was needed.  As a first step it was designed to communicate via a simple YAML status file.  Both applications reference a common status class with methods for reading and writing the status file.





**JSON-to-CSV Conversion notes**

We get asked about converting JSON data to CSV very frequently.  This is a very common request for one-time consumers of social data.  A typical scenario is someone conducting research and exploring signals from their domain in social media data.  [tweeting-in-the-rain example]

JSON formatting is dynamic in nature because it readily supports hashes and arrays of variable length. 

The process of converting tweets from JSON to CSV was much more complicated than anticipated. 

*Nominating JSON arrays for 'special' flattening*

config@arrays_to_collapse = 'hashtags,user_mentions,twitter_entities.urls,gnip.urls,matching_rules,topics'



*Supporting 'special' header mappings*

Default behavior is to use the dot-notation key by default, but some keys get silly-long:

    #twitter_entities.hashtags.0.text               --> hashtags
    #twitter_entities.urls.0.url                    --> twitter_urls
    #twitter_entities.urls.0.expanded_url           --> twitter_expanded_urls
    #twitter_entities.urls.0.display_url            --> twitter_display_urls
    #twitter_entities.user_mentions.0.screen_name   --> user_mention_screen_names
    #twitter_entities.user_mentions.0.name          --> user_mention_names
    #twitter_entities.user_mentions.0.id            --> user_mention_ids
    #gnip.matching_rules.0.value                    --> rule_values
    #gnip.matching_rules.0.tag                      --> tag_values
    
The above represent the current defaults that are automatically generated. These can be updated in the (YAML) config file.

These are specified at config@header_mappings.

        mappings['twitter_entities.hashtags.0.text'] = 'hashtags'
        mappings['twitter_entities.urls.0.url'] = 'twitter_urls'
        mappings['twitter_entities.urls.0.expanded_url'] = 'twitter_expanded_urls'
        mappings['twitter_entities.urls.0.display_url'] = 'twitter_display_urls'
        mappings['twitter_entities.user_mentions.0.screen_name'] = 'user_mention_screen_names'
        mappings['twitter_entities.user_mentions.0.name'] = 'user_mention_names'
        mappings['twitter_entities.user_mentions.0.id'] = 'user_mention_ids'
        mappings['gnip.matching_rules.0.value'] = 'rule_values'
        mappings['gnip.matching_rules.0.tag'] = 'rule_tags'
        mappings['gnip.language.value'] = 'gnip_lang'

        #Geographical metadata labels.
        mappings['location.geo.coordinates.0.0.0'] = 'box_sw_long'
        mappings['location.geo.coordinates.0.0.1'] = 'box_sw_lat'
        mappings['location.geo.coordinates.0.1.0'] = 'box_nw_long'
        mappings['location.geo.coordinates.0.1.1'] = 'box_nw_lat'
        mappings['location.geo.coordinates.0.2.0'] = 'box_ne_long'
        mappings['location.geo.coordinates.0.2.1'] = 'box_ne_lat'
        mappings['location.geo.coordinates.0.3.0'] = 'box_se_long'
        mappings['location.geo.coordinates.0.3.1'] = 'box_se_lat'
        mappings['geo.coordinates.0'] = 'point_long'
        mappings['geo.coordinates.1'] = 'point_lat'

        #These Klout topics need some help.
        mappings['gnip.klout_profile.topics.0.klout_topic_id'] = 'klout_topic_id'
        mappings['gnip.klout_profile.topics.0.display_name'] = 'klout_topic_name'
        mappings['gnip.klout_profile.topics.0.link'] = 'klout_topic_link'


**SSL certificate issues with Ruby on Windows**

Some useful links about the Ruby/net::https/SSL issue:
* http://blog.kabisa.nl/2009/12/04/ruby-and-ssl-certificate-validation/
* http://notetoself.vrensk.com/2008/09/verified-https-in-ruby/

If you are getting SSL certificate errors, try removing the "cacert.pem" in the local directory.
If that file is not found, this app will go out and create a fresh file from http://curl.haxx.se/ca/cacert.pem.


**Creating a Ruby executable on Windows**

This Ruby app is deployed on Windows using the Ocra gem:
* http://ocra.rubyforge.org/
* http://rubyonwindows.blogspot.com/2009/05/ocra-one-click-ruby-application-builder.html

If you want to make code changes, you can re-create the Windows executable with these commands:
* \pt_dm\ocra dm_process.rb --windows
* \pt_dm\ocra dm_ui.rb --windows --no-autoload
* 






