# iPXEAnywhere Scripts

These are scripts that are need for iPXE Webservice.
The required scripts are the following (and must be in the correct subfolder):

- Authentication\DeviceAuthentication.ps1
- Boot\iPXEboot.ps1
- Config\ \<All Scripts>

If using ConfigMgr the follwing is also recommended:
- ConfigMgr\defaultconfigmgr.ps1

The must be placed in the following default folder:  
_C:\Program Files\2Pint Software\iPXE AnywhereWS\Scripts_  
(If installed elsewhere adjust path accordingly)

When referencing another script the path is always relative the _iPXE AnywhereWS\Scripts_ folder

The rest of the scripts are not required but examples how to do different things with the 2Pint iPXE Webservice.

So using explorer it should look like something like this:  
![image](https://github.com/2pintsoftware/2Pint-iPXEAnywhere/assets/15101419/8b77b344-4bbb-46c5-bb88-54a9cf2f78ab)  

For documentation regarding 2Pint iPXE Webservice:
https://ipxews.docs.2pintsoftware.com/

For documentation regarding iPXE menus:
https://ipxe.org/docs

