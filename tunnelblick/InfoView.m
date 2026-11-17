/*
 * Copyright 2011, 2012, 2013, 2014, 2015, 2016, 2018 Jonathan K. Bullard. All rights reserved.
 *
 *  This file is part of Tunnelblick.
 *
 *  Tunnelblick is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License version 2
 *  as published by the Free Software Foundation.
 *
 *  Tunnelblick is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program (see the file COPYING included with this
 *  distribution); if not, write to the Free Software Foundation, Inc.,
 *  59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *  or see http://www.gnu.org/licenses/.
 */


#import "InfoView.h"

#import "helper.h"
#import "sharedRoutines.h"

#import "UIHelper.h"
#import "TBUserDefaults.h"


extern TBUserDefaults * gTbDefaults;
extern NSFileManager  * gFileMgr;
extern NSString       * gDeployPath;


@implementation InfoView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

-(void) dealloc {

	[logo release];           logo        = nil;

	[super dealloc];
}

- (void)drawRect:(NSRect)dirtyRect {
    // Drawing code here.
	(void) dirtyRect;
}

- (void) configureReadOnlyTextView: (NSTextView *) textView scrollView: (NSScrollView *) scrollView {
    [scrollView setHasHorizontalScroller: NO];
    [scrollView setHasVerticalScroller: YES];
    [scrollView setAutohidesScrollers: YES];

    // The nib's fixed minimum width prevents wrapping when the window shrinks.
    NSSize size = [scrollView contentSize];
    [textView setEditable: NO];
    [textView setHorizontallyResizable: NO];
    [textView setVerticallyResizable: YES];
    [textView setMinSize: NSMakeSize(0.0, size.height)];
    [textView setMaxSize: NSMakeSize(FLT_MAX, FLT_MAX)];
    [textView setAutoresizingMask: NSViewWidthSizable];
    [textView setTextContainerInset: NSMakeSize(6.0, 6.0)];
    [textView setFrameSize: size];
    [[textView textContainer] setContainerSize: NSMakeSize(MAX(1.0, size.width - 12.0), FLT_MAX)];
    [[textView textContainer] setWidthTracksTextView: YES];
    [[textView textContainer] setHeightTracksTextView: NO];
    [textView setContinuousSpellCheckingEnabled: NO];
    [textView setAutomaticSpellingCorrectionEnabled: NO];
    [textView setAllowsUndo: NO];
}

- (void) replaceString: (NSString *)                  oldString
            withString: (NSString *)                  newString
             urlString: (NSString *)                  urlString
                    in: (NSMutableAttributedString *) target {

    // Create the new string with a link in it
    NSMutableAttributedString* newAttrString = [[[NSMutableAttributedString alloc] initWithString: LocalizationNotNeeded(newString)] autorelease];

    NSURL * aURL = [NSURL URLWithString: urlString];
    if (  ! aURL  ) {
        NSLog(@"Invalid URL '%@'", urlString);
        return;
    }

    NSRange range = NSMakeRange(0, [newAttrString length]);

    [newAttrString beginEditing];

    [newAttrString addAttribute: NSLinkAttributeName value: [aURL absoluteString] range: range];

    // make the text appear in blue
    [newAttrString addAttribute: NSForegroundColorAttributeName value: [NSColor blueColor] range: range];

    // next make the text appear with an underline
    [newAttrString addAttribute: NSUnderlineStyleAttributeName value: [NSNumber numberWithInt: NSSingleUnderlineStyle] range: range];

    [newAttrString endEditing];

    // Now substitute that string for the old string
    range = [[target string] rangeOfString: oldString];
    if (  range.length == 0  ) {
        NSLog(@"Unable to find '%@' in '%@'", oldString, [target string]);
        return;
    }

    [target deleteCharactersInRange: range];
    [target insertAttributedString: newAttrString atIndex: range.location];
}

-(void) awakeFromNib
{
    NSString * logoPath = [[NSBundle mainBundle] pathForResource: @"tunnelblick" ofType: @"icns"];
    if (  logoPath  ) {
        [logo release];
        logo = [[NSImage alloc] initWithContentsOfFile: logoPath];
        [infoLogoIV setImage: logo];
    }

    [self configureReadOnlyTextView: infoDescriptionTV scrollView: infoDescriptionSV];
    [self configureReadOnlyTextView: infoCreditTV scrollView: infoCreditSV];

    // If Resources has an "about.html", use that as the base for the license description
    // Using [[NSBundle mainBundle] pathForResource: @"about" ofType: @"html"] doesn't always work -- it is apparently cached by macOS.
    // If it is used immediately after the installer creates and populates Resources/Deploy, nil is returned instead of the path
    // Using [[NSBundle mainBundle] resourcePath: ALSO seems to not work (don't know why, maybe the same reason)
    // The workaround is to create the path "by hand" and use that.
    NSString * aboutPath    = [[[NSBundle mainBundle] bundlePath] stringByAppendingString: @"/Contents/Resources/about.html"];
	NSString * htmlFromFile = [NSString stringWithContentsOfFile: aboutPath encoding:NSASCIIStringEncoding error:NULL];
    if (  htmlFromFile  ) {
        NSString * basedOnHtml  = NSLocalizedString(@"<br>Based on Tunnel" @"blick, free software available at<br><a href=\"https://tunnelblick.net\">https://tunnelblick.net</a><br><br>OpenVPN is a registered trademark of OpenVPN Inc.", @"Window text");
        NSString * html         = [NSString stringWithFormat:@"%@%@%@%@",
                                   @"<html><body><center><div style=\"font-family: Verdana, Arial, Helvetica, sans-serif; font-size: 10px\">",
                                   htmlFromFile,
                                   basedOnHtml,
                                   @"</div></center><body></html>"];
        NSMutableAttributedString * description = [[attributedStringFromHTML(html) mutableCopy] autorelease];
		[description addAttribute: NSForegroundColorAttributeName value:[NSColor textColor]           range: NSMakeRange(0, [description length])];
        [[infoDescriptionTV textStorage] setAttributedString: description];
    } else {

        // Create the base string with localized content (the leading space is needed to keep the prefix from becoming a link; it is removed if the prefix is not needed)
		NSString * localizedContent = NSLocalizedString(@" %1$@ is free software: you can redistribute it and/or modify it under the terms of the %2$@ as published by the %3$@.\n\n%4$@ is a registered trademark of OpenVPN Inc.", @"Window text");
        NSMutableAttributedString * descriptionString = [[[NSMutableAttributedString alloc] initWithString: localizedContent] autorelease];

        // Replace the placeholders in the localized content with links
        [self replaceString: @"%1$@"
                 withString: @"Tunnel" @"blick"
                  urlString: @"https://tunnelblick.net"
                         in: descriptionString];

        [self replaceString: @"%2$@"
                 withString: @"GNU General Public License version 2"
                  urlString: @"https://www.gnu.org/licenses/gpl-2.0.html"
                         in: descriptionString];

        [self replaceString: @"%3$@"
                 withString: @"Free Software Foundation"
                  urlString: @"https://fsf.org"
                         in: descriptionString];

        [self replaceString: @"%4$@"
                 withString: @"OpenVPN"
                  urlString: @"https://openvpn.net/"
                         in: descriptionString];

        // If Tunnelblick has been globally replaced with XXX, prefix the license description with "XXX is based on Tunnelblick."
        if (   ( ! [gTbDefaults boolForKey: @"doNotUnrebrandLicenseDescription"]  )
			&& ( ! [@"Tunnelblick" isEqualToString: @"Tunnel" @"blick"]  )
			) {
			NSString * prefix = [NSString stringWithFormat:
								 NSLocalizedString(@"Tunnelblick is based on %@.", @"Window text"),
								 @"Tunnel" @"blick"];
			[descriptionString replaceCharactersInRange: NSMakeRange(0, 0) withString: prefix];
        } else {
			[descriptionString deleteCharactersInRange: NSMakeRange(0, 1)];	// Remove leading space
        }

		[descriptionString addAttribute: NSForegroundColorAttributeName value:[NSColor textColor]           range: NSMakeRange(0, [descriptionString length])];
        [descriptionString addAttribute: NSFontAttributeName value: [NSFont systemFontOfSize: [NSFont systemFontSize]] range: NSMakeRange(0, [descriptionString length])];
        [[infoDescriptionTV textStorage] setAttributedString: descriptionString];
    }

    // Append the TOTP description below the license; the version area already contains its heading.
    {
        NSString * totpBody = NSLocalizedString(@"\n\nThis version can store a Google Authenticator root secret for each VPN credentials group. When enabled, Tunnelblick generates the current six-digit security code when you connect and appends it to your password.\n\nThe root secret is stored in the macOS Keychain on this computer. Anyone with access to this computer or the secret can generate your security codes. Do not share the QR code or secret with others. If this device is lost or compromised, revoke and re-create the two-factor authentication secret on the VPN server.", @"Window text");

        NSMutableAttributedString * totpAttr = [[[NSMutableAttributedString alloc] initWithString: totpBody] autorelease];
        NSRange bodyRange = NSMakeRange(0, [totpBody length]);
        [totpAttr addAttribute: NSForegroundColorAttributeName value: [NSColor textColor] range: bodyRange];
        [totpAttr addAttribute: NSFontAttributeName value: [NSFont systemFontOfSize: [NSFont systemFontSize]] range: bodyRange];
        [[infoDescriptionTV textStorage] appendAttributedString: totpAttr];
    }

    // Keep all contributor names and localized roles in native attributed text.

    NSArray * mainCredits = @[
                             @[@"Angelo Laub",      NSLocalizedString(@"Founder, original program and documentation",  @"Credit description")],
                             @[@"James Yonan",      @"OpenVPN"],
                             @[@"Dirk Theisen",     NSLocalizedString(@"Contributed much to the early code",           @"Credit description")],
                             @[@"Jonathan Bullard", NSLocalizedString(@"Program and documentation enhancements and maintenance since 2010", @"Credit description")],

                             @[
                              NSLocalizedString(@"LEAD_TRANSLATORS",      @"Names of lead translators"),
                              NSLocalizedString(@"LANGUAGE_TRANSLATION",  @"[name of your language] translation")]
							 ];

    NSArray * pgmCredits = @[
                            @[@"Dave Batton",                  @"DBPrefsWindowController"],
                            @[@"Michael Schloh von Bennewit",  NSLocalizedString(@"64-bit enabling and testing",           @"Credit description")],
                            @[@"Stefan Bethke",                NSLocalizedString(@"Localization code tweaks",              @"Credit description")],
                            @[@"Michael Bianco",               NSLocalizedString(@"Button images",                         @"Credit description")],
                            @[@"Waldemar Brodkorb",            NSLocalizedString(@"Contributed to early code",             @"Credit description")],
                            @[@"Math Campbell",                NSLocalizedString(@"Button images",                         @"Credit description")],
                            @[@"William Faulk",                NSLocalizedString(@"Icon set including Retina images",      @"Credit description")],
                            @[@"Matt Gemmell",                                   @"NSAttachedWindow"],
                            @[@"Raal Goff",                    NSLocalizedString(@"Animation and icon sets code",          @"Credit description")],
                            @[@"Benji Greig",                  NSLocalizedString(@"Tunnelblick icon",                      @"Credit description")],
                            @[@"Mohammad A. Haque",            NSLocalizedString(@"Xcode help and OpenSSL integration",    @"Credit description")],
                            @[@"Wyatt Kirby",                  NSLocalizedString(@"Icon set including Retina images",      @"Credit description")],
                            @[@"Uli Kusterer",                 NSLocalizedString(@"UKKQueue and UKLoginItemRegistry",      @"Credit description")],
                            @[@"Xaver Loppenstedt",            NSLocalizedString(@"PKCS#11 support",                       @"Credit description")],
                            @[@"Andy Matuschak",                                 @"Sparkle"],
                            @[@"Dustin Mierau",                                  @"Netsocket"],
                            @[@"Harold Molina-Bulla",          NSLocalizedString(@"OpenVPN 2.3 and 64-bit integration",    @"Credit description")],
                            @[@"Mattias Nissler",                                @"Tuntap"],
                            @[@"Markus F. X. J. Oberhumer",                      @"LZO"],
                            @[@"Jens Ohlig",                   NSLocalizedString(@"Contributed to early code",             @"Credit description")],
                            @[@"Diego Rivera",                 NSLocalizedString(@"Up and Down scripts",                   @"Credit description")],
                            @[@"Michael Williams",             NSLocalizedString(@"Multiple configuration folders",        @"Credit description")],
                            @[@"Nick Williams",                NSLocalizedString(@"Up and Down scripts",                   @"Credit description")]
							];

    NSArray * locCredits = @[
							@[@"Sobhi Abufool",                 NSLocalizedString(@"Arabic translation",                   @"Credit description")],
                            @[@"Khalid Alhumud",                NSLocalizedString(@"Arabic translation",                   @"Credit description")],
							@[@"Ali#",							 NSLocalizedString(@"Persian translation",                 @"Credit description")],
							@[@"Vittorio Anselmo",				 NSLocalizedString(@"Italian translation",                 @"Credit description")],
							@[@"Felin Arch",					 NSLocalizedString(@"Hungarian translation",               @"Credit description")],
							@[@"Alejandro Azadte",              NSLocalizedString(@"Spanish translation",                  @"Credit description")],
                            @[@"b123400",                       NSLocalizedString(@"Chinese (traditional) translation",    @"Credit description")],
                            @[@"Matej Bačík",                   NSLocalizedString(@"Slovak translation",                   @"Credit description")],
                            @[@"Ian Barnes",                    NSLocalizedString(@"Afrikaans translation",                @"Credit description")],
                            @[@"Beining",                       NSLocalizedString(@"Chinese (simplified) translation",     @"Credit description")],
                            @[@"Stefan Bethke",                 NSLocalizedString(@"German translation",                   @"Credit description")],
                            @[@"Simon Biber",					NSLocalizedString(@"Chinese (traditional) translation",    @"Credit description")],
							@[@"Simon Biber",					NSLocalizedString(@"Chinese (simplified) translation",     @"Credit description")],
                            @[@"Rachid BM",                     NSLocalizedString(@"Dutch translation",                    @"Credit description")],
							@[@"Dariusz Bogdanski",             NSLocalizedString(@"Polish translation",                   @"Credit description")],
                            @[@"Olivier Borowski",              NSLocalizedString(@"French translation",                   @"Credit description")],
                            @[@"Martin Bratteng",               NSLocalizedString(@"Norwegian translation",                @"Credit description")],
                            @[@"Charlie Brown",                 NSLocalizedString(@"Vietnamese translation",               @"Credit description")],
                            @[@"Miguel C.",                     NSLocalizedString(@"Portuguese translation",               @"Credit description")],
							@[@"Alican Cakil",                  NSLocalizedString(@"Turkish translation",                  @"Credit description")],
                            @[@"Sergio Andrés Castro Cárdenas", NSLocalizedString(@"Spanish translation",                  @"Credit description")],
							@[@"Lubomir Carik",                 NSLocalizedString(@"Slovak translation",                   @"Credit description")],
							@[@"Adam Černý",                    NSLocalizedString(@"Czech translation",                    @"Credit description")],
                            @[@"cert.lv",                       NSLocalizedString(@"Latvian translation",                  @"Credit description")],
							@[@"Teerapap Changwichukarn",       NSLocalizedString(@"Thai translation",    				   @"Credit description")],
							@[@"Zhanchong Chen",                NSLocalizedString(@"Chinese (simplified) translation",     @"Credit description")],
                            @[@"Vadim Chumachenko",             NSLocalizedString(@"Ukrainian translation",                @"Credit description")],
                            @[@"Iris Coeligena",                NSLocalizedString(@"Turkish translation",                  @"Credit description")],
							@[@"Diego Silva Cogo",              NSLocalizedString(@"Portuguese (Brazilian) translation",   @"Credit description")],
                            @[@"Catalin Comanici",              NSLocalizedString(@"Romanian translation",                 @"Credit description")],
                            @[@"Mats Cronqvist",                NSLocalizedString(@"Swedish translation",                  @"Credit description")],
                            @[@"Grzegorz Danecki",              NSLocalizedString(@"Polish translation",                   @"Credit description")],
							@[@"Mohamad Deek",                  NSLocalizedString(@"Arabic translation",                   @"Credit description")],
							@[@"Martin Doktár",                 NSLocalizedString(@"Swedish translation",                  @"Credit description")],
							@[@"Sergiy Dolnyy",                 NSLocalizedString(@"Ukrainian translation",                @"Credit description")],
                            @[@"Aleix Dorca",                   NSLocalizedString(@"Catalan translation",                  @"Credit description")],
                            @[@"Andreas Finke",                 NSLocalizedString(@"German translation",                   @"Credit description")],
							@[@"Marco Firsching",               NSLocalizedString(@"German translation",                   @"Credit description")],
							@[@"FoghDesign",                    NSLocalizedString(@"Danish translation",                   @"Credit description")],
                            @[@"Emīls Gailišs",                 NSLocalizedString(@"Latvian translation",                  @"Credit description")],
                            @[@"Simone Gianni",                 NSLocalizedString(@"Italian translation",                  @"Credit description")],
                            @[@"Nail Gilmanov",                 NSLocalizedString(@"Russian translation",                  @"Credit description")],
                            @[@"Igor Gojkovic",                 NSLocalizedString(@"Croatian translation",                 @"Credit description")],
                            @[@"Igor Gojkovic",                 NSLocalizedString(@"Serbian (Latin) translation",          @"Credit description")],
							@[@"Oleksandr Golubets",            NSLocalizedString(@"Ukrainian translation",                @"Credit description")],
                            @[@"Massimo Grassi",                NSLocalizedString(@"Italian translation",                  @"Credit description")],
                            @[@"Ricardo Guijt",                 NSLocalizedString(@"Dutch translation",                    @"Credit description")],
                            @[@"Pierpaolo Gulla",               NSLocalizedString(@"Italian translation",                  @"Credit description")],
							@[@"Robbert Hamburg CISA, CISSP, CEH", NSLocalizedString(@"Dutch translation",                 @"Credit description")],
							@[@"Robbert Hamburg CISA, CISSP, CEH", NSLocalizedString(@"Flemish translation",               @"Credit description")],
                            @[@"Takatoh Herminghaus",           NSLocalizedString(@"German translation",                   @"Credit description")],
                            @[@"Oliver Hill",                   NSLocalizedString(@"French translation",                   @"Credit description")],
							@[@"Cam Hoang",                     NSLocalizedString(@"Vietnamese translation",               @"Credit description")],
                            @[@"'Dr Hok'",                      NSLocalizedString(@"German translation",                   @"Credit description")],
                            @[@"Evandro Curvelo Hora",          NSLocalizedString(@"Portuguese (Brazilian) translation",   @"Credit description")],
							@[@"Johan Hornof",                  NSLocalizedString(@"Czech translation",                    @"Credit description")],
                            @[@"Igor Hrček",                    NSLocalizedString(@"Serbian (Latin) translation",          @"Credit description")],
							@[@"Jesse Hulkko",                  NSLocalizedString(@"Finnish translation",                  @"Credit description")],
							@[@"Christophe Icard",              NSLocalizedString(@"French translation",                   @"Credit description")],
							@[@"Bogdan I. Iorga",               NSLocalizedString(@"Romanian translation",                 @"Credit description")],
                            @[@"Jarmo Isotalo",                 NSLocalizedString(@"Finnish translation",                  @"Credit description")],
							@[@"Vlad Iuga",              		NSLocalizedString(@"Romanian translation",                 @"Credit description")],
							@[@"Ronny Jordalen",                NSLocalizedString(@"Norwegian translation",                @"Credit description")],
                            @[@"Dewey Kang",                    NSLocalizedString(@"Korean translation",                   @"Credit description")],
                            @[@"Yunseok Kang",                  NSLocalizedString(@"Korean translation",                   @"Credit description")],
							@[@"Tuomo Karhu",                   NSLocalizedString(@"Finnish translation",                  @"Credit description")],
							@[@"Kalle Kärkkäinen",              NSLocalizedString(@"Finnish translation",                  @"Credit description")],
							@[@"Yoshihisa Kawamoto",            NSLocalizedString(@"Japanese translation",                 @"Credit description")],
                            @[@"Alexander Kaydannik",           NSLocalizedString(@"Ukrainian translation",                @"Credit description")],
                            @[@"Kornél Keszthelyi",             NSLocalizedString(@"Hungarian translation",                @"Credit description")],
                            @[@"Kyoungmin Kim",                 NSLocalizedString(@"Korean translation",                   @"Credit description")],
                            @[@"Jan Klat",                      NSLocalizedString(@"Czech translation",                    @"Credit description")],
                            @[@"Laurens de Knijff",             NSLocalizedString(@"Dutch translation",                    @"Credit description")],
							@[@"Matti Kohtala",                 NSLocalizedString(@"Finnish translation",                  @"Credit description")],
                            @[@"Mikael Kolkinn",                NSLocalizedString(@"Norwegian translation",                @"Credit description")],
                            @[@"Kiriaki Konstantinidou",        NSLocalizedString(@"Greek translation",                    @"Credit description")],
                            @[@"Andrejs Kotovs",                NSLocalizedString(@"Latvian translation",                  @"Credit description")],
                            @[@"Andreas Kromke",                NSLocalizedString(@"German translation",                   @"Credit description")],
                            @[@"kskmt",                         NSLocalizedString(@"Japanese translation",                 @"Credit description")],
                            @[@"Henry Kuo",                     NSLocalizedString(@"Chinese (traditional) translation",    @"Credit description")],
                            @[@"Emin Kura",                     NSLocalizedString(@"Turkish translation",                  @"Credit description")],
                            @[@"Daniel Kvist",                  NSLocalizedString(@"Swedish translation",                  @"Credit description")],
                            @[@"Isaac Kwan",                    NSLocalizedString(@"Chinese (traditional) translation",    @"Credit description")],
                            @[@"Aming Lau",                     NSLocalizedString(@"Chinese (traditional) translation",    @"Credit description")],
                            @[@"Aleksey Likholob",              NSLocalizedString(@"Ukrainian translation",                @"Credit description")],
                            @[@"Débora Lima",                   NSLocalizedString(@"Portuguese translation",               @"Credit description")],
							@[@"Débora Lima",                   NSLocalizedString(@"Portuguese (Brazilian) translation",   @"Credit description")],
							@[@"Yen-Ting Liu",                  NSLocalizedString(@"Chinese (traditional) translation",    @"Credit description")],
                            @[@"Jon Luberth",                   NSLocalizedString(@"Norwegian translation",                @"Credit description")],
                            @[@"Łukasz M",                      NSLocalizedString(@"Polish translation",                   @"Credit description")],
                            @[@"Jakob Bo Søndergaard Madsen",   NSLocalizedString(@"Danish translation",                   @"Credit description")],
                            @[@"Mehrad Mahmoudian",             NSLocalizedString(@"Persian translation",                  @"Credit description")],
							@[@"Tim Malmström",                 NSLocalizedString(@"Swedish translation",                  @"Credit description")],
							@[@"Dušan Marjanović",              NSLocalizedString(@"Serbian (Latin) translation",          @"Credit description")],
							@[@"Luigi Martini",                 NSLocalizedString(@"Italian translation",                  @"Credit description")],
                            @[@"Denis Volpato Martins",         NSLocalizedString(@"Portuguese (Brazilian) translation",   @"Credit description")],
							@[@"Klaus Marx",                    NSLocalizedString(@"German translation",                   @"Credit description")],
							@[@"Dr. Joseph Mbowe",              NSLocalizedString(@"Swahili (Tanzania) translation",       @"Credit description")],
							@[@"Gema Megantara",            	 NSLocalizedString(@"Indonesian translation",              @"Credit description")],
							@[@"Rustam Mehmandarov",            NSLocalizedString(@"Azerbaijani translation",              @"Credit description")],
							@[@"Rustam Mehmandarov",            NSLocalizedString(@"Norwegian translation",                @"Credit description")],
							@[@"Rustam Mehmandarov",            NSLocalizedString(@"Russian translation",                  @"Credit description")],
                            @[@"Atakan Meray",                  NSLocalizedString(@"Turkish translation",                  @"Credit description")],
                            @[@"Boian Mihailov",                NSLocalizedString(@"Bulgarian translation",                @"Credit description")],
							@[@"Robin De Mol",                  NSLocalizedString(@"Flemish translation",                  @"Credit description")],
                            @[@"Koen Moulaert",                 NSLocalizedString(@"Flemish translation",                  @"Credit description")],
                            @[@"Richárd Murvai",                NSLocalizedString(@"Hungarian translation",                @"Credit description")],
                            @[@"Andrejs Mors-Jaroslavcevs",     NSLocalizedString(@"Latvian translation",                  @"Credit description")],
							@[@"Max Naylor",                    NSLocalizedString(@"Icelandic translation",                @"Credit description")],
                            @[@"Kalan Nguyen",                  NSLocalizedString(@"Japanese translation",                 @"Credit description")],
                            @[@"Kurt Jarusutthirak Nielsen",    NSLocalizedString(@"Danish translation",                   @"Credit description")],
							@[@"Nikki",                         NSLocalizedString(@"Azerbaijani translation",              @"Credit description")],
                            @[@"Johan Nilsson",                 NSLocalizedString(@"Swedish translation",                  @"Credit description")],
							@[@"Mattias Nilsson",               NSLocalizedString(@"Swedish translation",                  @"Credit description")],
                            @[@"Feetu Nyrhinen",                NSLocalizedString(@"Finnish translation",                  @"Credit description")],
                            @[@"Kenji Obata",                   NSLocalizedString(@"Japanese translation",                 @"Credit description")],
                            @[@"Peter K. O'Connor",             NSLocalizedString(@"Chinese (simplified) translation",     @"Credit description")],
                            @[@"Tzvika Ofek",					 NSLocalizedString(@"Hebrew translation",                  @"Credit description")],
                            @[@"Stig A. Olsen",                 NSLocalizedString(@"Norwegian translation",                @"Credit description")],
                            @[@"Tzanos Panagiotis",             NSLocalizedString(@"Greek translation",                    @"Credit description")],
							@[@"La Pegunta Foundation",         NSLocalizedString(@"Catalan translation",                  @"Credit description")],
                            @[@"Petra Penttila",                NSLocalizedString(@"Finnish translation",                  @"Credit description")],
                            @[@"Matteo Pillon",                 NSLocalizedString(@"Italian translation",                  @"Credit description")],
                            @[@"Ioannis Pinakoulakis",          NSLocalizedString(@"Greek translation",                    @"Credit description")],
                            @[@"Lionel Pinkhard",               NSLocalizedString(@"Afrikaans translation",                @"Credit description")],
                            @[@"Victor Ptichkin",               NSLocalizedString(@"Russian translation",                  @"Credit description")],
                            @[@"Ricardo Rezende",               NSLocalizedString(@"Portuguese (Brazilian) translation",   @"Credit description")],
                            @[@"Diego Rivera",                  NSLocalizedString(@"Spanish translation",                  @"Credit description")],
                            @[@"Nicolas Rodriguez (Tupaca)",    NSLocalizedString(@"Spanish translation",                  @"Credit description")],
							@[@"Minho Ryang",                   NSLocalizedString(@"Korean translation",                   @"Credit description")],
							@[@"Darek Rzeźnicki",               NSLocalizedString(@"Polish translation",                   @"Credit description")],
							@[@"Murat Salma",               	NSLocalizedString(@"Turkish translation",                  @"Credit description")],
							@[@"Michoel Samuels",               NSLocalizedString(@"Hebrew translation",                   @"Credit description")],
                            @[@"Saulo Santos",                  NSLocalizedString(@"Portuguese translation",               @"Credit description")],
                            @[@"Ranal Saron",                   NSLocalizedString(@"Estonian translation",                 @"Credit description")],
                            @[@"Markus Schneider",              NSLocalizedString(@"German translation",                   @"Credit description")],
                            @[@"Janek Schwarz",                 NSLocalizedString(@"German translation",                   @"Credit description")],
                            @[@"Emma Segev",                    NSLocalizedString(@"Dutch translation",                    @"Credit description")],
                            @[@"Jeremy Sherman",                NSLocalizedString(@"French translation",                   @"Credit description")],
                            @[@"Þór Sigurðsson",                NSLocalizedString(@"Icelandic translation",                @"Credit description")],
							@[@"D. Simeonidis",                 NSLocalizedString(@"Greek translation",                    @"Credit description")],
                            @[@"Stjepan Siljac",                NSLocalizedString(@"Swedish translation",                  @"Credit description")],
                            @[@"SitesME",                       NSLocalizedString(@"Portuguese translation",               @"Credit description")],
                            @[@"Emīls Skujiņš",                 NSLocalizedString(@"Latvian translation",                  @"Credit description")],
                            @[@"Tjalling Soldaat",              NSLocalizedString(@"Dutch translation",                    @"Credit description")],
							@[@"Arne Solheim",                  NSLocalizedString(@"Norwegian translation",                @"Credit description")],
							@[@"Xavier Spirlet (Petitpoisson)", NSLocalizedString(@"French translation",                   @"Credit description")],
                            @[@"Petr Šrajer",                   NSLocalizedString(@"Czech translation",                    @"Credit description")],
                            @[@"Wojciech Sromek",               NSLocalizedString(@"Polish translation",                   @"Credit description")],
                            @[@"Ann-Charlotte Storer",          NSLocalizedString(@"Swedish translation",                  @"Credit description")],
                            @[@"Mihail Stoynov",                NSLocalizedString(@"Bulgarian translation",                @"Credit description")],
							@[@"Alexander Strashilov",          NSLocalizedString(@"Bulgarian translation",                @"Credit description")],
							@[@"Zack Strulovitch",              NSLocalizedString(@"Hebrew translation",                   @"Credit description")],
                            @[@"Allan Sun",                     NSLocalizedString(@"Chinese (traditional) translation",    @"Credit description")],
                            @[@"Benedek Szabó",                 NSLocalizedString(@"Hungarian translation",                @"Credit description")],
                            @[@"Marcell Szabo",                 NSLocalizedString(@"Hungarian translation",                @"Credit description")],
                            @[@"Paul Taykalo",                  NSLocalizedString(@"Ukrainian translation",                @"Credit description")],
                            @[@"Thanh Nguyen",                  NSLocalizedString(@"Vietnamese translation",               @"Credit description")],
                            @[@"TheFrog",                       NSLocalizedString(@"Slovak translation",                   @"Credit description")],
                            @[@"Erwann Thoraval",               NSLocalizedString(@"French translation",                   @"Credit description")],
                            @[@"Mikko Toivola",                 NSLocalizedString(@"Finnish translation",                  @"Credit description")],
                            @[@"André Torres",                  NSLocalizedString(@"Portuguese translation",               @"Credit description")],
                            @[@"Andika Triwidada",              NSLocalizedString(@"Indonesian translation",               @"Credit description")],
							@[@"Roman Truba",					 NSLocalizedString(@"Russian translation",                 @"Credit description")],
                            @[@"Eugene Trufanov",               NSLocalizedString(@"Russian translation",                  @"Credit description")],
                            @[@"Dennis Ukhanov",                NSLocalizedString(@"Russian translation",                  @"Credit description")],
                            @[@"Caglar Ulkuderner",             NSLocalizedString(@"Turkish translation",                  @"Credit description")],
							@[@"Levi Ustinov",                  NSLocalizedString(@"Russian translation",                  @"Credit description")],
                            @[@"François Varas",                NSLocalizedString(@"French translation",                   @"Credit description")],
                            @[@"Jorge Daniel Sampayo Vargas",   NSLocalizedString(@"Spanish translation",                  @"Credit description")],
                            @[@"Cristiano Verondini",           NSLocalizedString(@"Italian translation",                  @"Credit description")],
                            @[@"Zoltan Lanyi Webmegoldasok",    NSLocalizedString(@"Hungarian translation",                @"Credit description")],
                            @[@"Pomin Wu",                      NSLocalizedString(@"Chinese (traditional) translation",    @"Credit description")],
                            @[@"Kun Xi",                        NSLocalizedString(@"Chinese (simplified) translation",     @"Credit description")],
                            @[@"Sho Yano",                      NSLocalizedString(@"Japanese translation",                 @"Credit description")],
                            @[@"Andrew Ying",                   NSLocalizedString(@"Chinese (traditional) translation",    @"Credit description")],
							@[@"Abraham van der Vyver",         NSLocalizedString(@"Afrikaans translation",                @"Credit description")],
                            @[@"游精展",                         NSLocalizedString(@"Chinese (traditional) translation",    @"Credit description")],
							@[@"Cagri Yucel",                   NSLocalizedString(@"Turkish translation",                  @"Credit description")],
                            @[@"Magdelena Zajac",               NSLocalizedString(@"Polish translation",                   @"Credit description")],
                            @[@"Omri Zamir",                    NSLocalizedString(@"Hebrew translation",                   @"Credit description")],
							@[@"ZaTi",                          NSLocalizedString(@"Romanian translation",                 @"Credit description")],
                            @[@"Nikolay Zhelev",                NSLocalizedString(@"Bulgarian translation",                @"Credit description")],
							@[@"Zozzi",                         NSLocalizedString(@"Slovak translation",                   @"Credit description")]
                            ];

    // HTML tables force expensive NSTextTable layout on the main thread while
    // scrolling. Plain paragraphs wrap cheaply at every supported window width.
    NSMutableAttributedString * creditsString = [[[NSMutableAttributedString alloc] init] autorelease];
    NSMutableParagraphStyle * bodyStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [bodyStyle setAlignment: NSNaturalTextAlignment];
    [bodyStyle setBaseWritingDirection: ([UIHelper languageAtLaunchWasRTL] ? NSWritingDirectionRightToLeft : NSWritingDirectionLeftToRight)];
    [bodyStyle setParagraphSpacing: 8.0];
    NSMutableParagraphStyle * headingStyle = [[bodyStyle mutableCopy] autorelease];
    [headingStyle setAlignment: NSCenterTextAlignment];
    [headingStyle setParagraphSpacingBefore: 12.0];
    [headingStyle setParagraphSpacing: 12.0];

    NSDictionary * bodyAttributes = @{NSFontAttributeName: [NSFont systemFontOfSize: [NSFont systemFontSize]],
                                      NSForegroundColorAttributeName: [NSColor textColor],
                                      NSParagraphStyleAttributeName: bodyStyle};
    NSDictionary * headingAttributes = @{NSFontAttributeName: [NSFont boldSystemFontOfSize: [NSFont systemFontSize]],
                                         NSForegroundColorAttributeName: [NSColor textColor],
                                         NSParagraphStyleAttributeName: headingStyle};
    NSArray * groups = @[mainCredits, pgmCredits, locCredits];
    NSArray * headings = @[NSLocalizedString(@"TUNNELBLICK is brought to you by", @"Window text"),
                           NSLocalizedString(@"Additional contributions by", @"Window text"),
                           NSLocalizedString(@"Translation by", @"Window text")];
    for (NSUInteger groupIndex = 0; groupIndex < [groups count]; groupIndex++) {
        NSAttributedString * heading = [[[NSAttributedString alloc] initWithString: [[headings objectAtIndex: groupIndex] stringByAppendingString: @"\n"]
                                                                       attributes: headingAttributes] autorelease];
        [creditsString appendAttributedString: heading];
        NSString * previousName = nil;
        for (NSArray * row in [groups objectAtIndex: groupIndex]) {
            NSString * name = [row objectAtIndex: 0];
            NSString * role = [row objectAtIndex: 1];
            if (groupIndex == 0) {
                if ([name isEqualToString: @"LEAD_TRANSLATORS"]) {
                    continue;
                }
                if ([role isEqualToString: @"LANGUAGE_TRANSLATION"]) {
                    role = @"Translation leaders";
                }
            }
            if (groupIndex == 2 && [previousName isEqualToString: name]) {
                name = @"";
            } else {
                previousName = name;
            }
            NSString * text = ([name length] == 0
                              ? [role stringByAppendingString: @"\n"]
                              : [NSString stringWithFormat: @"%@ — %@\n", name, role]);
            NSMutableAttributedString * credit = [[[NSMutableAttributedString alloc] initWithString: text attributes: bodyAttributes] autorelease];
            if ([name length] != 0) {
                [credit addAttribute: NSFontAttributeName value: [NSFont boldSystemFontOfSize: [NSFont systemFontSize]] range: NSMakeRange(0, [name length])];
            }
            [creditsString appendAttributedString: credit];
        }
    }
    [[infoCreditTV textStorage] setAttributedString: creditsString];
    [infoCopyrightTFC setTitle: copyrightNotice()];
}

-(void) newViewDidAppear: (NSView *) view
{
    (void) view;
}

-(void) newViewWillAppear: (NSView *) view identifier: (NSString *) identifier
{
    (void) view;
    (void) identifier;

    // Credits stay still until the user scrolls, so this page has no recurring
    // timer or continuous text redraws and remains readable.
    [infoCreditTV scrollPoint: NSZeroPoint];
    [infoDescriptionTV scrollPoint: NSZeroPoint];
}

// Show the fork version in bold, followed by the TOTP variant label in red.
-(void) updateVersionDisplay
{
    NSString * deployedString = (  gDeployPath && [gFileMgr fileExistsAtPath: gDeployPath]
                                 ? NSLocalizedString(@" (Deployed)", @"Window title")
                                 : @"");
    NSString * versionLine = [NSString stringWithFormat: @"%@%@", tunnelblickVersion([NSBundle mainBundle]), deployedString];
    NSString * totpLine    = NSLocalizedString(@"Automatic Security Code (TOTP) Version", @"Window text");
    NSString * fullText    = [NSString stringWithFormat: @"%@\n%@", versionLine, totpLine];

    NSFont * versionFont = [NSFont boldSystemFontOfSize: [NSFont systemFontSize]];
    NSFont * totpFont    = [NSFont systemFontOfSize: [NSFont systemFontSize]];

    NSMutableAttributedString * attrString = [[[NSMutableAttributedString alloc] initWithString: fullText] autorelease];

    NSRange versionRange = NSMakeRange(0, [versionLine length]);
    [attrString addAttribute: NSForegroundColorAttributeName value: [NSColor controlTextColor] range: versionRange];
    [attrString addAttribute: NSFontAttributeName value: versionFont range: versionRange];

    NSRange totpRange = NSMakeRange([versionLine length] + 1, [totpLine length]);
    [attrString addAttribute: NSForegroundColorAttributeName value: [NSColor systemRedColor] range: totpRange];
    [attrString addAttribute: NSFontAttributeName value: totpFont range: totpRange];

    NSTextField * versionField = (NSTextField *)[infoVersionTFC controlView];
    if (  versionField  ) {
        [versionField setEditable: NO];
        [versionField setSelectable: NO];
        [versionField setAllowsEditingTextAttributes: NO];
        [versionField setRefusesFirstResponder: YES];
        [versionField setAttributedStringValue: attrString];
    } else {
        [infoVersionTFC setTitle: fullText];
    }
}

TBSYNTHESIZE_OBJECT_GET(retain, NSTextFieldCell *, infoVersionTFC)

@end
