#import <Foundation/Foundation.h>
#include <CoreFoundation/CoreFoundation.h>
#import <SpringBoardServices/SpringBoardServices.h>
#import <dlfcn.h>
#include <curl/curl.h>


NSString * getFrontMostApplication() {
    mach_port_t p = SBSSpringBoardServerPort();
    char frontmostAppS[256];
    memset(frontmostAppS, 0, sizeof(frontmostAppS));
    SBFrontmostApplicationDisplayIdentifier(p, frontmostAppS);
    
    NSString * frontmostApp = [NSString stringWithFormat:@"%s", frontmostAppS];
    NSLog(@"dmon: Frontmost app is: %@", frontmostApp);
    return (frontmostApp);
}

NSString * installedPogoVersion(void) {
    NSLog(@"dmon: Finding Pogo version...");
    char bundlePath[150]; // This should never be longer than 100 but we added a buffer
    FILE *pogo_cmd = popen("find /var/containers/Bundle/Application/ -type d -name 'PokmonGO.app'", "r");
    if (pogo_cmd == NULL) {
        NSLog(@"dmon: Unable to find PokemonGo on device");
        return nil;
    }

    fgets(bundlePath, sizeof(bundlePath), pogo_cmd);
    pclose(pogo_cmd);
    bundlePath[strcspn(bundlePath, "\n")] = '\0'; // Remove newline character
    sprintf(bundlePath, "%s/Info.plist", bundlePath);

    NSString *path = [[NSString alloc] initWithUTF8String:bundlePath];
    NSDictionary *infoDict = [[NSDictionary alloc] initWithContentsOfFile:path];
    NSString *versionString = [infoDict objectForKey:@"CFBundleShortVersionString"];
    NSLog(@"dmon: Installed version of Pokemon Go: %@", versionString);
    return versionString;
}

NSString * installedGCVersion(void) {
    // Can't use this really clean method since this library isn't versioned. Big Sad!
    // NSBundle *goCheatsBundle = [NSBundle bundleWithPath:@"/Library/MobileSubstrate/DynamicLibraries/libgocheats.dylib"];
    // NSLog(@"dmon: bundle info is: %@", goCheatsBundle);
    // NSString *goCheatsVersion = [goCheatsBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    // NSLog(@"dmon: Version: %@", goCheatsVersion);
    // return goCheatsVersion;

    NSLog(@"dmon: Finding GC version...");
    FILE *gc_cmd = popen("apt list 2>/dev/null | grep -i gocheats | cut -d ' ' -f 2", "r");
    if (gc_cmd == NULL) {
        NSLog(@"dmon: Unable to find GC version");
        return nil;
    }

    char version[256];
    int bytesRead = fread(version, sizeof(char), 255, gc_cmd);
    version[bytesRead] = '\0';
    pclose(gc_cmd);
    version[strcspn(version, "\n")] = '\0'; // Remove newline character

    NSLog(@"dmon: Installed version of GC: %s", version);
    return [[NSString alloc] initWithUTF8String:version];
}

NSDictionary * parseConfig(void) {
    NSString *filePath = @"/var/mobile/Application Support/GoCheats/config.json";
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    NSError *error;
    NSData *fileData = [NSData dataWithContentsOfURL:fileURL options:NSDataReadingMappedIfSafe error:&error];

    if (fileData) {
        NSError *jsonError;
        NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:fileData options:NSJSONReadingMutableContainers error:&jsonError];
        
        if (jsonObject) {
            // Successfully parsed the JSON data
            return jsonObject;
        } else {
            // Failed to parse the JSON data
            NSLog(@"dmon: Error parsing JSON: %@", jsonError);
        }
    } else {
        // Failed to read the file data
        NSLog(@"dmon: Error reading file: %@", error);
    }
    return nil;
}

NSMutableDictionary * parseKeyValueFileAtPath(NSString *filePath) {
    NSMutableDictionary *resultDict = [NSMutableDictionary dictionary];
    
    NSError *error = nil;
    NSString *fileContents = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        NSLog(@"dmon: Error reading file: %@", error);
        return nil;
    }
    
    NSArray *lines = [fileContents componentsSeparatedByString:@"\n"];
    for (NSString *line in lines) {
        NSArray *parts = [line componentsSeparatedByString:@": "];
        if (parts.count == 2) {
            NSString *key = parts[0];
            NSString *value = parts[1];
            [resultDict setObject:value forKey:key];
        }
    }
    
    return resultDict;
}

int killall(NSString *appName) {
    NSLog(@"dmon: Stopping appName: %@", appName);
    int stop_pid;
    char command[100]; // Make it large enough.
    sprintf(command, "killall %s 2>/dev/null", [appName UTF8String]);
    FILE *stop_pid_cmd = popen(command, "r");
    fscanf(stop_pid_cmd, "%d", &stop_pid);
    pclose(stop_pid_cmd);
    return stop_pid;
}

int installIpa(NSString *filePath) {
    NSLog(@"dmon: Installing: %@...", filePath);
    int results;
    char command[100];
    sprintf(command, "appinst %s", [filePath UTF8String]);
    FILE *install_ipa_cmd = popen(command, "r");
    fscanf(install_ipa_cmd, "%d", &results);
    pclose(install_ipa_cmd);
    return results;
}

int installDeb(NSString *filePath) {
    NSLog(@"dmon: Installing: %@...", filePath);
    int ext_code;
    char deb_command[100];
    sprintf(deb_command, "dpkg -i %s", [filePath UTF8String]);
    FILE *install_deb_cmd = popen(deb_command, "r");
    char output[100];
    while (fgets(output, sizeof(output), install_deb_cmd) != NULL) {
        NSLog(@"dmon: dpkg output: %s", output);
    }
    ext_code = pclose(install_deb_cmd);
    NSLog(@"dmon: Results for %@ are: %d", filePath, ext_code);
    return ext_code;
}

int downloadFile(NSString *url, NSString *userpass, NSString *outfile) {
    CURL *curl;
    CURLcode res = -1;
    FILE *fp;
    curl = curl_easy_init();

    if (curl) {
        // Set the URL
        curl_easy_setopt(curl, CURLOPT_URL, [url UTF8String]);
        
        // Set the authentication headers
        curl_easy_setopt(curl, CURLOPT_HTTPAUTH, CURLAUTH_BASIC);
        curl_easy_setopt(curl, CURLOPT_USERPWD, [userpass UTF8String]);
        
        // Set the output file
        fp = fopen([outfile UTF8String], "wb");
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, fp);

        // Perform the request
        res = curl_easy_perform(curl);
        NSLog(@"dmon: Curl return code for %@: %u", url, res);

        // Clean up
        fclose(fp);
        curl_easy_cleanup(curl);
    }
    return res;
}

void update(NSDictionary *config) {
    NSString *versionFile = @"version.txt";
    NSString *pogo_ipa = @"pogo.ipa";
    NSString *gc_deb = @"gc.deb";
    NSString *pogoVersion = installedPogoVersion();
    NSString *gcVersion = installedGCVersion();

    // Strip trailing forward slashes to make things consistent for users
    NSString *url = [config[@"dmon_url"] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
    NSLog(@"dmon: Update URL is: %@", url);
    downloadFile(
        [NSString stringWithFormat:@"%@/%@", url, versionFile],
        [NSString stringWithFormat:@"%@:%@", config[@"dmon_username"], config[@"dmon_password"]],
        versionFile
    );

    // Parse the config map style version.txt to NSDictionary
    NSMutableDictionary *parsedVersion = parseKeyValueFileAtPath(versionFile);

    // Update Pogo if needed
    if (![pogoVersion isEqualToString:parsedVersion[@"pogo"]]) {
        NSLog(@"dmon: Pogo version mismatch. Have %@. Need %@", pogoVersion, parsedVersion[@"pogo"]);
        int pogoDownload = downloadFile(
            [NSString stringWithFormat:@"%@/%@", url, pogo_ipa],
            [NSString stringWithFormat:@"%@:%@", config[@"dmon_username"], config[@"dmon_password"]],
            pogo_ipa
        );
        // TODO: Do we need a stricter validation?
        if (pogoDownload == 0) {
            installIpa(pogo_ipa);
        }
    }

    // Update GC if needed
    if (![gcVersion isEqualToString:parsedVersion[@"gc"]]) {
        NSLog(@"dmon: GC version mismatch. Have %@. Need %@", gcVersion, parsedVersion[@"gc"]);
        int gcDownload = downloadFile(
            [NSString stringWithFormat:@"%@/%@", url, gc_deb],
            [NSString stringWithFormat:@"%@:%@", config[@"dmon_username"], config[@"dmon_password"]],
            gc_deb
        );
        // TODO: Do we need a stricter validation?
        if (gcDownload == 0) {
            installDeb(gc_deb);
        }
    }
}

void monitor(void) {
    NSString *currentApp = getFrontMostApplication();
    if (![currentApp isEqualToString:@"com.nianticlabs.pokemongo"]) {
        NSLog(@"dmon: Restarting Kernbypass...");
        killall(@"/usr/bin/kernbypass");
        NSLog(@"dmon: Force stopping Pogo...");
        killall(@"pokemongo");
        sleep(2);
        NSLog(@"dmon: Pogo not running. Launch it...");
        // Launch Pogo
        void* sbServices = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
        int (*SBSLaunchApplicationWithIdentifier)(CFStringRef identifier, Boolean suspended) = dlsym(sbServices, "SBSLaunchApplicationWithIdentifier");
        NSString *bundleString=[NSString stringWithUTF8String:"com.nianticlabs.pokemongo"];
        int result = SBSLaunchApplicationWithIdentifier((__bridge CFStringRef)bundleString, NO);
        NSLog(@"dmon: Launch Pogo: %d", result);
        dlclose(sbServices);
    }
}

int main(void) {
    NSLog(@"dmon: Starting...");

    // Start loop
    int i = 0;
    while (1) {
        // Only call at the start of loop
        if (i == 0) {
            NSDictionary *config = parseConfig();
            // NSLog(@"dmon: Full config: %@", config);
            update(config);
        }

        // Call this function every loop
        monitor();

        // Restart loop on the 30th iteration
        if (++i == 30) {
            i = 0;
        }

        sleep(30);
    }
    return 0;
}
