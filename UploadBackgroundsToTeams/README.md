# Upload Backgrounds To Teams

Bash script to upload a list of backgrounds from a public repo to the user's Teams background folder.
First images are downloaded from the public repo [Slingshot Aerospace Background Images](https://github.com/steven-giang-van/BackgroundImages), which will then be uploaded to the Teams backgrounds folder.
The script will create a thumbnail image so that it can be selectable in the backgrounds menu.

Background images: [Slingshot Aerospace Background Images](https://github.com/steven-giang-van/BackgroundImages)


To find the folder where Teams upload the backgrounds, open Terminal and run the following command:
```
find ~/Library -name "*Uploads*" 2>/dev/null
```
This will output the folder path to the backgrounds folder.

**ADVICE:** It's highly recommended to have end-users remove the backgrounds they've uploaded or else duplicates will show.
Have them navigate to the folder and simply run
```
rm *
```
To remove all uploaded backgrounds.
