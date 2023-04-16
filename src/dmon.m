#include <SpringBoardServices/SpringBoardServices.h>
#include <sys/sysctl.h>
#include <dlfcn.h>
#include <curl/curl.h>

@interface LSResourceProxy : NSObject
@end

@interface LSBundleProxy : LSResourceProxy
    @property (nonatomic, readonly) NSString *localizedShortName;
@end

@interface LSApplicationProxy : LSBundleProxy
    @property (nonatomic, readonly) NSString *applicationType;
    @property (nonatomic, readonly) NSString *applicationIdentifier;
    @property(readonly) NSURL * dataContainerURL;
    @property(readonly) NSURL * bundleContainerURL;
    @property(readonly) NSString * localizedShortName;
    @property(readonly) NSString * localizedName;
@end

@interface LSApplicationWorkspace : NSObject
    + (id)defaultWorkspace;
    - (BOOL)installApplication:(NSURL *)path withOptions:(NSDictionary *)options;
    - (BOOL)uninstallApplication:(NSString *)identifier withOptions:(NSDictionary *)options;
    - (id)allApplications;
    - (id)allInstalledApplications;
    - (BOOL)applicationIsInstalled:(id)arg1;
    - (id)applicationsOfType:(unsigned int)arg1;
@end

NSString *getFrontMostApplication() {
    mach_port_t p = SBSSpringBoardServerPort();
    char frontmostAppS[256];
    memset(frontmostAppS, 0, sizeof(frontmostAppS));
    SBFrontmostApplicationDisplayIdentifier(p, frontmostAppS);
    
    NSString *frontmostApp = [NSString stringWithFormat:@"%s", frontmostAppS];
    NSLog(@"dmon: Frontmost app is: %@", frontmostApp);
    return (frontmostApp);
}

NSDictionary *getAptList(NSString *packageName) {
    NSDictionary *result = [NSDictionary dictionary];
    NSString *dpkStatusFile = @"/var/lib/dpkg/status";
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:dpkStatusFile];

    if (fileHandle) {
        // Read the contents of the file
        NSData *fileData = [fileHandle readDataToEndOfFile];
        // Convert the file data to a string
        NSString *fileString = [[NSString alloc] initWithData:fileData encoding:NSUTF8StringEncoding];
        // Close the file handle
        [fileHandle closeFile];
        // Convert the file data to a dictionary
        NSArray *packages = [fileString componentsSeparatedByString:@"\n\n"];
        
        for (NSString *packageString in packages) {
            NSMutableDictionary *packageDict = [NSMutableDictionary dictionary];
            NSArray *packageLines = [packageString componentsSeparatedByString:@"\n"];
            
            for (NSString *line in packageLines) {
                NSArray *keyValue = [line componentsSeparatedByString:@": "];
                if (keyValue.count == 2) {
                    packageDict[keyValue[0]] = keyValue[1];
                }
            }

            if ([packageDict[@"Package"] isEqualToString:packageName]) {
                NSLog(@"dmon: Version of %@: %@", packageName, packageDict[@"Version"]);
                return packageDict;
            }
        }
    }
    else {
        NSLog(@"dmon: Failed to open file for reading: %@", dpkStatusFile);
    }
    return result;
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

void terminateProcessWithName(NSString *processName) {
    // Declare variables
    struct kinfo_proc *processes;
    size_t size;
    int sysctlResult;

    // Get the size of the buffer required to hold the process list
    sysctlResult = sysctlbyname("kern.proc.all", NULL, &size, NULL, 0);
    if (sysctlResult != 0) {
        NSLog(@"dmon: Failed to get process count");
        return;
    }

    // Allocate the buffer for the process list
    processes = malloc(size);
    if (processes == NULL) {
        NSLog(@"dmon: Failed to allocate process list buffer");
        return;
    }

    // Get the list of running processes
    sysctlResult = sysctlbyname("kern.proc.all", processes, &size, NULL, 0);
    if (sysctlResult != 0) {
        NSLog(@"dmon: Failed to get process list");
        free(processes);
        return;
    }

    // Iterate over the process list and stop the correct process
    for (int i = 0; i < size / sizeof(struct kinfo_proc); i++) {
        struct kinfo_proc process = processes[i];
        NSString *procName = [NSString stringWithUTF8String:process.kp_proc.p_comm];
        if ([procName isEqualToString:processName]) {
            pid_t pid = process.kp_proc.p_pid;
            kill(pid, SIGKILL); // SIGTERM or SIGKILL
            NSLog(@"dmon: Process '%@' (PID %d) terminated", procName, pid);
            break;
        }
    }

    // Free the buffer
    free(processes);
}

int installIpa(NSString *filePath) {
    NSLog(@"dmon: Installing: %@...", filePath);
    int results;
    char command[100];
    sprintf(command, "appinst %s", [filePath UTF8String]);
    FILE *install_ipa_cmd = popen(command, "r");
    fscanf(install_ipa_cmd, "%d", &results);
    pclose(install_ipa_cmd);
    NSLog(@"dmon: Results for %@ are: %d", filePath, results);
    if (remove([filePath UTF8String]) != 0) {
        NSLog(@"Failed to delete the file %@", filePath);
    }
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
    // Delete the package install
    if (remove([filePath UTF8String]) != 0) {
        NSLog(@"Failed to delete the file %@", filePath);
    }
    return ext_code;
}

int downloadFile(NSString *url, NSString *userpass, NSString *outfile) {
    CURL *curl;
    FILE *fp;
    long httpCode = -1;
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

        // Set the path to the cacerts file
        curl_easy_setopt(curl, CURLOPT_CAINFO, "/usr/lib/ssl/cacert.pem");

        // Perform the request
        CURLcode res = curl_easy_perform(curl);

        // Get the http status code
        curl_easy_getinfo (curl, CURLINFO_RESPONSE_CODE, &httpCode);

        // Clean up
        fclose(fp);
        curl_easy_cleanup(curl);

        // Check for successful download
        if (res == CURLE_OK && httpCode >= 200 && httpCode < 300) {
            NSLog(@"dmon: Download was sucessful: %ld", httpCode);
            return 0;
        } else {
            NSLog(@"dmon: Download failed with error code: %ld", httpCode);
            // Delete the outfile if it exists
            if (remove([outfile UTF8String]) != 0) {
                NSLog(@"Failed to delete the file %@", outfile);
            }
        }
    }
    return -1;
}

NSDictionary *installedAppInfo(NSString * bundleID) {
    LSApplicationWorkspace *workspace = [NSClassFromString(@"LSApplicationWorkspace") defaultWorkspace];
    for (LSApplicationProxy *proxy in [workspace applicationsOfType:0]) {
        if ([[proxy applicationIdentifier] isEqualToString: bundleID]) {
            NSString *bundlePath = [proxy bundleContainerURL].path;

            // This might be a bad assumption. I only checked it with PokemonGO
            NSString *infoFile = [NSString stringWithFormat:@"%@.app/Info.plist", [proxy localizedShortName]];
            bundlePath = [bundlePath stringByAppendingPathComponent: infoFile];
            NSDictionary *infoDict = [[NSDictionary alloc] initWithContentsOfFile:bundlePath];
            NSString *versionString = [infoDict objectForKey:@"CFBundleShortVersionString"];

            NSDictionary *dict = @{@"bundle_name" : [proxy localizedShortName],
                                @"bundle_id" : [proxy applicationIdentifier],
                                @"bundle_version" : versionString,
                                @"bundle_path" : [proxy bundleContainerURL].path};
            NSLog(@"dmon: Version of %@: %@", bundleID, versionString);
            return dict;
        }
    }
    return nil;
}

void stopBypassAndPogo(void) {
    NSLog(@"dmon: Force stopping PokemonGo...");
    terminateProcessWithName(@"PokmonGO");
    sleep(5);
    NSLog(@"dmon: Restarting Kernbypass...");
    terminateProcessWithName(@"kernbypass");
}

void update(NSDictionary *config) {
    NSString *versionFile = @"version.txt";
    NSString *pogo_ipa = @"pogo.ipa";
    NSString *gc_deb = @"gc.deb";
    NSString *dmon_deb = @"dmon.deb";
    NSString *pogoVersion = installedAppInfo(@"com.nianticlabs.pokemongo")[@"bundle_version"];
    NSString *gcVersion = getAptList(@"com.gocheats.jb")[@"Version"];
    NSString *dmonVersion = getAptList(@"com.github.clburlison.dmon")[@"Version"];

    // Strip trailing forward slashes to make things consistent for users
    NSString *url = [config[@"dmon_url"] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
    NSLog(@"dmon: Update URL is: %@", url);
    int versionDownload = downloadFile(
        [NSString stringWithFormat:@"%@/%@", url, versionFile],
        [NSString stringWithFormat:@"%@:%@", config[@"dmon_username"], config[@"dmon_password"]],
        versionFile
    );
    if (versionDownload != 0) {
        NSLog(@"dmon: Unable to process updates as %@ is invalid", versionFile);
        return;
    }

    // Parse the config map style version.txt to NSDictionary
    NSMutableDictionary *parsedVersion = parseKeyValueFileAtPath(versionFile);

    // If any component needs to be updated we should stop Pokemon Go
    if (
            ![dmonVersion isEqualToString:parsedVersion[@"dmon"]] ||
            ![pogoVersion isEqualToString:parsedVersion[@"pogo"]] ||
            ![gcVersion isEqualToString:parsedVersion[@"gc"]]
        ) {
        stopBypassAndPogo();
    }


    // Update dmon if needed
    if (![dmonVersion isEqualToString:parsedVersion[@"dmon"]]) {
        NSLog(@"dmon: dmon version mismatch. Have '%@'. Need '%@'", dmonVersion, parsedVersion[@"dmon"]);
        int gcDownload = downloadFile(
            [NSString stringWithFormat:@"%@/%@", url, dmon_deb],
            [NSString stringWithFormat:@"%@:%@", config[@"dmon_username"], config[@"dmon_password"]],
            dmon_deb
        );
        if (gcDownload == 0) {
            installDeb(dmon_deb);
        }
    }

    // Update Pogo if needed
    if (![pogoVersion isEqualToString:parsedVersion[@"pogo"]]) {
        NSLog(@"dmon: Pogo version mismatch. Have '%@'. Need '%@'", pogoVersion, parsedVersion[@"pogo"]);
        int pogoDownload = downloadFile(
            [NSString stringWithFormat:@"%@/%@", url, pogo_ipa],
            [NSString stringWithFormat:@"%@:%@", config[@"dmon_username"], config[@"dmon_password"]],
            pogo_ipa
        );
        if (pogoDownload == 0) {
            installIpa(pogo_ipa);
        }
    }

    // Update GC if needed
    if (![gcVersion isEqualToString:parsedVersion[@"gc"]]) {
        NSLog(@"dmon: GC version mismatch. Have '%@'. Need '%@'", gcVersion, parsedVersion[@"gc"]);
        int gcDownload = downloadFile(
            [NSString stringWithFormat:@"%@/%@", url, gc_deb],
            [NSString stringWithFormat:@"%@:%@", config[@"dmon_username"], config[@"dmon_password"]],
            gc_deb
        );
        if (gcDownload == 0) {
            installDeb(gc_deb);
        }
    }
}

void monitor(void) {
    NSString *currentApp = getFrontMostApplication();
    if (![currentApp isEqualToString:@"com.nianticlabs.pokemongo"]) {
        stopBypassAndPogo();

        // Launch Pogo
        NSLog(@"dmon: PokemonGo not running. Launch it...");
        void* sbServices = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
        int (*SBSLaunchApplicationWithIdentifier)(CFStringRef identifier, Boolean suspended) = dlsym(sbServices, "SBSLaunchApplicationWithIdentifier");
        NSString *bundleString=[NSString stringWithUTF8String:"com.nianticlabs.pokemongo"];
        int result = SBSLaunchApplicationWithIdentifier((__bridge CFStringRef)bundleString, NO);
        NSLog(@"dmon: PokemonGo Launch Results: %d", result);
        dlclose(sbServices);
    }
}

int main(void) {
    NSLog(@"dmon: Starting...");

    // Start loop
    int i = 0;
    while (1) {
        NSDictionary *config = parseConfig();
        if (i == 0 && config[@"dmon_url"] != nil && [config[@"dmon_url"] isKindOfClass:[NSString class]] && ![config[@"dmon_url"] isEqualToString:@""]) {
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
