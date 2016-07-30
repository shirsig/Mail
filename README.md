# Postal - WoW 1.12 addOn

A lightweight extension to the default mail interface which lets you
- **Automatically open mails**
- **Mail multiple items at once**

There were two very similar (to eachother) Vanilla mail addOns commonly found in collections: GMail and CT_MailMod. Both were using the same terrible mechanism for automation, unnecessarily making them extremely slow, had a rather ugly send interface and would not hide the "New Mail"-notifier after opening the last mail automatically.

This addOn solves all those problems, being **super fast**, adapting the **style of the retail send frame** and correctly **hiding the notifier**. (the problem there is actually a bug in the wow client and the icon will reappear after doing a /reload. This cannot be prevented.)

I started this as a modification of *grennon*'s GMail and named after GMail's retail version.

Note that because due to limitations of the 1.12 API behind the scenes the items have to be sent in separate mails.
As a result of this **COD will only apply to the first item** if multiple items are added.

![Alt text](http://i.imgur.com/sN0H39Z.png)

![Alt text](http://i.imgur.com/T44FFUS.png)

![Alt text](http://i.imgur.com/whkGMWA.png)
