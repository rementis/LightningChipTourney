#!/usr/bin/perl

########################################################
#                                                      #
# Lightening Chip Tourney                              #
#     Martin Colello                                   #
#   April/May/June 2018                                #
#                                                      #
# Add move table Aug 2018                              #
#                                                      #
# Add player db Oct 2018                               #
#                                                      #
# Auto shuffle when only two players left May 2019     #
#                                                      #
# Add ability to undo most recent win June 2020        #
#                                                      #
# Add time tracking June 2021                          #
#                                                      #
# Add split screen June 2021                           #
#                                                      #
# Fix too long player name issue July 2021             #
#                                                      #
# Fix fargo missing from log issue Aug 2021            #
#                                                      #
# Add Forfeit subroutine September 2021                #
#                                                      #
# Fix issue with user containing spaces Sep 2021       #
#                                                      #
# Add five levels of undo Oct 2021                     #
#                                                      #
# Store tournament name and create xls report Oct 2021 #
#                                                      #
# Add Send to Undo November 2021                       #
#                                                      #
# Add bottom bar and adjust position Dec 2021          #
#                                                      #
# Increase to three columns Dec 2021                   #
#                                                      #
# Capitalize first letter of each word in player name  #
# Dec 2021                                             #
#                                                      #
# Create remote display                                #
# Jan 2021                                             #
#                                                      #
# Automated version check                              #
# Jan 2021                                             #
#                                                      #
# Remove question for fargo ID as it's rarely used     #
# Jan 2021                                             #
#                                                      #
#                                                      #
########################################################

use strict;
use HTTP::Tiny;
use Term::ReadKey;
use List::Util 'shuffle';
use Term::ANSIColor;
use POSIX;
use Array::Columnize;
use Storable;
use Storable qw/dclone/;
use Excel::Writer::XLSX;
use Net::SFTP;
use Net::Ping;
use File::Path qw( make_path );
use if $^O eq "MSWin32", "Win32::Sound";

$SIG{INT} = 'IGNORE';

# Get current date
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
if ( $min < 10 ) { $min = "0$min" }
if ( $sec < 10 ) { $sec = "0$sec" }
$year = $year + 1900;

my @abbr = qw(January February March April May June July August September October November December);
if ( $hour > 12 ) {
  $hour = $hour - 12;
}
my $DATE  = "$hour".'_'."$min"."_$sec"."_$abbr[$mon]"."_$mday"."_$year";
my $DATE2 = "$abbr[$mon]"."_$mday"."_$year";

# Set files
my $status                   = "$DATE".'status.html';
my $remote_display           = 'remote_display.txt';
my $fargo_storage_file       = 'fargo.txt';
my $tournament_name          = 'tournament_name.txt';
my $chip_rating_storage_file = 'chip_rating.txt';
my $player_db                = 'chip_player.txt';
my $storable_send            = 'storable_send.txt';
my $storable_players         = 'storable_players.txt';
my $storable_tables          = 'storable_tables.txt';
my $storable_dead            = 'storable_dead.txt';
my $storable_stack           = 'storable_stack.txt';
my $storable_whobeat         = 'storable_whobeat.txt';
my $storable_whobeat_csv     = 'storable_whobeat_csv.txt';
my $storable_tourney_running = 'storable_tourney_running.txt';
my $namestxt                 = 'names.txt';
#my $desktop                 = 'chip_results_'."$abbr[$mon]"."_$mday"."_$year".'.txt';
my $desktop                  = 'chip_results_'."$DATE".'.txt';
#my $desktop_csv             = 'chip_results_'."$abbr[$mon]"."_$mday"."_$year".'.csv';
my $desktop_csv              = 'chip_results_'."$DATE".'.csv';
#my $outfile_xlsx            = 'chip_results_'."$abbr[$mon]"."_$mday"."_$year".'.xlsx';
my $outfile_xlsx             = 'chip_results_'."$DATE".'.xlsx';

if ( $^O =~ /MSWin32/ ) {
  system("title Lightning Tournament");
  chomp(my $profile = `set userprofile`);
  $profile          =~ s/userprofile=//i;
  my $homedir       = $profile . "\\desktop\\Chip_Results";

  # If desktop folder exists do nothing, if not then create it
  if ( -d $homedir ) {
    print "Homedir $homedir exists.\n";
  } else {
    make_path($homedir);
  }

  $desktop      = $profile . "\\desktop\\Chip_Results\\$desktop";
  $desktop_csv  = $profile . "\\desktop\\Chip_Results\\$desktop_csv";
  $outfile_xlsx = $profile . "\\desktop\\Chip_Results\\$outfile_xlsx";


  if ( exists $ENV{'LOCALAPPDATA'} ) {
    my $local_app_data        = $ENV{'LOCALAPPDATA'};
    $status                   = "$local_app_data\\$status";
    $remote_display           = "$local_app_data\\$remote_display";
    $fargo_storage_file       = "$local_app_data\\$fargo_storage_file";
    $chip_rating_storage_file = "$local_app_data\\$chip_rating_storage_file";
    $player_db                = "$local_app_data\\$player_db";
    $storable_send            = "$local_app_data\\$storable_send";
    $storable_players         = "$local_app_data\\$storable_players";
    $storable_tables          = "$local_app_data\\$storable_tables";
    $storable_dead            = "$local_app_data\\$storable_dead";
    $storable_stack           = "$local_app_data\\$storable_stack";
    $storable_whobeat         = "$local_app_data\\$storable_whobeat";
    $storable_whobeat_csv     = "$local_app_data\\$storable_whobeat_csv";
    $storable_tourney_running = "$local_app_data\\$storable_tourney_running";
    $namestxt                 = "$local_app_data\\$namestxt";
    $tournament_name          = "$local_app_data\\$tournament_name";
  } else {
    $status                   = $profile . "\\desktop\\$status";
    $remote_display           = $profile . "\\desktop\\$remote_display";
    $fargo_storage_file       = $profile . "\\desktop\\$fargo_storage_file";
    $chip_rating_storage_file = $profile . "\\desktop\\$chip_rating_storage_file";
    $player_db                = $profile . "\\desktop\\$player_db";
    $storable_send            = $profile . "\\desktop\\$storable_send";
    $storable_players         = $profile . "\\desktop\\$storable_players";
    $storable_tables          = $profile . "\\desktop\\$storable_tables";
    $storable_dead            = $profile . "\\desktop\\$storable_dead";
    $storable_stack           = $profile . "\\desktop\\$storable_stack";
    $storable_whobeat         = $profile . "\\desktop\\$storable_whobeat";
    $storable_whobeat_csv     = $profile . "\\desktop\\$storable_whobeat_csv";
    $storable_tourney_running = $profile . "\\desktop\\$storable_tourney_running";
    $namestxt                 = $profile . "\\desktop\\$namestxt";
    $tournament_name          = $profile . "\\desktop\\$tournament_name";
  }
}


# Hold state of screen in case we need to exit program
my $screen_contents;

# Keep record of number of players so we can split screen if needed
my $master_number_of_players = 0;

# Set outfile for final results
my $outfile     = "$desktop";
my $outfile_csv = "$desktop_csv";

# Open log file
#print "outfile is $outfile\n";
open (OUTFILE,'>',$outfile) or die "Cannot open results file: $!";
print OUTFILE "$abbr[$mon]".' '."$mday".' '."$year"."\n";
print OUTFILE "Lightning Chip Tourney results:                      --by Martin Colello\n\n";

# Setup some global hashes and variables
my $version = 'v9.76';           # Installed version of software
my $remote_server_check = 1;     # Trigger whether or not to use sftp
my $remote_user;                 # User id for remote display
my $remote_pass;                 # Password for remote display
my $remote_server;               # Remote server for display
my $color  = 'bold white';       # Default text color to start with
my $key;                         # Generic holder for hash keys
my %players;                     # Hash which contains tourney players
my %tables;                      # Hash which contains billiard tables in use
my $tourney_running = 0;         # Determine if tourney is currently started
my @stack;                       # Array used to keep the players in order
my @dead;                        # Hold list of players with zero chips
my @whobeat;                     # Record who beat who
my @whobeat_csv;                 # Record who beat who for spreadsheet
my $Colors = 'on';               # Keep track if user wants color display turned off
my $player_standup = 'none';     # For undo tracking
my $game = 'none';               # Store game type (8/9/10 ball)
my $event;                       # Store Event name (Martin's Chip Tourney etc)
my $shuffle_mode = 'off';        # Keep track of shuffle mode off/on
my $send = 'none';               # Keep track of send new player to table information
my $undo_last_loser_count = 0;   # Keep track of level of undo
my $undo_fargo_id;
my $undo_won;
my $undo_chips;
my $tourney_name;
my $shuffle_mode_undo    = 'off';
my $shuffle_mode_undo2   = 'off';
my $shuffle_mode_undo3   = 'off';
my $shuffle_mode_undo4   = 'off';
my $shuffle_mode_undo5   = 'off';
my $shuffle_mode_restart = 'off';
my $send1 = "\n\n";
my $send2 = "\n\n";
my $send3 = "\n\n";
my $send4 = "\n\n";
my $send5 = "\n\n";
my $send_restart = "\n\n";
my %backup_players;
my %backup_players2;
my %backup_players3;
my %backup_players4;
my %backup_players5;
my %backup_players_restart;
my %backup_tables;
my %backup_tables2;
my %backup_tables3;
my %backup_tables4;
my %backup_tables5;
my %backup_tables_restart;
my @backup_dead;
my @backup_dead2;
my @backup_dead3;
my @backup_dead4;
my @backup_dead5;
my @backup_dead_restart;
my @backup_stack;
my @backup_stack2;
my @backup_stack3;
my @backup_stack4;
my @backup_stack5;
my @backup_stack_restart;
my @backup_whobeat;
my @backup_whobeat2;
my @backup_whobeat3;
my @backup_whobeat4;
my @backup_whobeat5;
my @backup_whobeat_restart;
my @backup_whobeatcsv;
my @backup_whobeatcsv2;
my @backup_whobeatcsv3;
my @backup_whobeatcsv4;
my @backup_whobeatcsv5;
my @backup_whobeatcsv_restart;
my $chips_8 = 461;
my $chips_7 = 521;
my $chips_6 = 581;
my $chips_5 = 641;
my $chips_4 = 1001;
my $check_version = version();

read_remote_display();

print color($color) unless ( $Colors eq 'off');

# Set the size of the console
if ( $^O =~ /MSWin32/ ) {
  system("mode con lines=35 cols=140");
}
if ( $^O =~ /darwin/ ) {
  system("osascript -e 'tell app \"Terminal\" to set background color of first window to {0, 0, 0, -16373}'");
  system("osascript -e 'tell app \"Terminal\" to set font size of first window to \"12\"'");
  system("osascript -e 'tell app \"Terminal\" to set bounds of front window to {300, 30, 1200, 900}'");
}

# If names.txt exits populate the tourney with sample data
if ( -e $namestxt ) {
  my $filename = $namestxt;
  open my $handle, '<', $filename;
  my @names = <$handle>;
  close $handle;
  chomp(@names);
  foreach(@names) {
    my $line = $_;
    my @split = split /:/, $line;
    my $player_name = $split[0];
    $players{$player_name}{'chips'} = $split[1];
    $players{$player_name}{'table'} = $split[2];
    $players{$player_name}{'fargo_id'} = $split[3];
    $players{$player_name}{'won'} = 0;
  }
  $tables{'5'}=1;
}
if ( -e $tournament_name ) {
  my $filename = $tournament_name;
  open my $handle, '<', $filename;
  $tourney_name = <$handle>;
  chomp($tourney_name);
  close $handle;
}

# print Lightning Chip Logo
print "\n\n\n\n\n";
print " _     _       _     _         _                ____ _     _       \n";
print "| |   (_) __ _| |__ | |_ _ __ (_)_ __   __ _   / ___| |__ (_)_ __  \n";
print "| |   | |/ _` | '_ \\| __| '_ \\| | '_ \\ / _` | | |   | '_ \\| | '_ \\ \n";
print "| |___| | (_| | | | | |_| | | | | | | | (_| | | |___| | | | | |_)|\n";
print "|_____|_|\\__, |_| |_|\\__|_| |_|_|_| |_|\\__, |  \\____|_| |_|_| .__/ \n";
print "         |___/                         |___/                |_|    \n\n\n\n\n\n";
print "                                           --by Martin Colello\n";

# Play sound effect
if ( $^O =~ /MSWin32/ ) {
  Win32::Sound::Play("lightning.wav");
}
if ( $^O =~ /linux/ ) {
  my $paplay = '/usr/bin/paplay';
  if ( -e $paplay ) {
    system '/usr/bin/paplay', 'lightning.wav';
  }
}

sleep 1;

game_and_event();

# MAIN LOOP of program
while(1) {

  # Delete players who have zero chips
  delete_players();

  # Draw the screen
  draw_screen();

  # Get list of players from hash
  my @players = keys(%players);

  # Get number of players left in tourney
  my $number_of_players = @players;

  # Check to see if tourney is over
  my $tables_in_use = 0;
  foreach(@players) {
    my $player = $_;
    if ( $players{$player}{'table'} !~ /none/ ) {
      $tables_in_use++;
    }
  }
  if ( $tourney_running eq 1 ) {
    #if (( $number_of_players < 2 ) or ( $tables_in_use eq 0 )){
    if ( $number_of_players < 2 ){
      draw_screen();
      print "\nEnd of tourney.\n";

      # Print list of who beat who to log file
      @whobeat = sort(@whobeat);
      foreach(@whobeat) {
	my $line = $_;
        print OUTFILE "$_";
      }
      close OUTFILE;

      history();

      # Open log file
      #if ( $^O =~ /MSWin32/     ) { system("start notepad.exe \"$desktop\"") }
      #if ( $^O =~ /MSWin32/     ) { system (1,"\"$desktop\"") }
      if ( $^O =~ /next|darwin/ ) { system("open $desktop") }
      print "\n\nThank you for using Lightning Chip Tourney!\n\n";
      sleep 2;
      delete_storable();
      exit;
    }
  }

  # Build menu
  my $done = 0;
  my $choice;
  ReadMode 4;
  undef($key);
  while ( !$done ) {
    if ( defined( $key = ReadKey(-1) ) ) {
      $choice = uc ( $key);
      $done = 1 if $choice eq 'Q';
      $done = 1 if $choice eq 'N';
      $done = 1 if $choice eq 'A';
      $done = 1 if $choice eq 'D';
      $done = 1 if $choice eq 'I';
      $done = 1 if $choice eq 'G';
      $done = 1 if $choice eq 'R';
      $done = 1 if $choice eq 'T';
      $done = 1 if $choice eq 'C';
      $done = 1 if $choice eq 'P';
      $done = 1 if $choice eq 'S';
      if ( $tourney_running eq 1 ) {
        $done = 1 if $choice eq 'M';
        $done = 1 if $choice eq 'H';
        $done = 1 if $choice eq 'L';
        $done = 1 if $choice eq 'U';
        $done = 1 if $choice eq 'E';
        $done = 1 if $choice eq 'Y';
        $done = 1 if $choice eq 'F';
      }
      if ( $tourney_running eq 0 ) {
        $done = 1 if $choice eq 'B';
      }
    }
  }
  ReadMode 0;

  # Call subroutines based on menu selection
  if ( $choice eq 'Q'  ) { quit_program()       }
  if ( $choice eq 'N'  ) { new_player()         }
  if ( $choice eq 'D'  ) { delete_player()      }
  if ( $choice eq 'A'  ) { new_table()          }
  if ( $choice eq 'R'  ) { delete_table()       }
  if ( $choice eq 'B'  ) { start_tourney()      }
  if ( $choice eq 'G'  ) { give_chip()          }
  if ( $choice eq 'T'  ) { take_chip()          }
  if ( $choice eq 'L'  ) { loser()              }
  if ( $choice eq 'E'  ) { enter_shuffle_mode() }
  if ( $choice eq 'C'  ) { switch_colors()      }
  if ( $choice eq 'M'  ) { move_player()        }
  if ( $choice eq 'H'  ) { history()            }
  if ( $choice eq 'P'  ) { new_player_from_db() }
  if ( $choice eq 'I'  ) { edit_player_db()     }
  if ( $choice eq 'U'  ) { undo_last_loser()    }
  if ( $choice eq 'F'  ) { forfeit()            }
  if ( $choice eq 'Y'  ) { list_players()       }
  if ( $choice eq 'S'  ) { 
    if ( $tourney_running eq 0 ) { 
      setup_remote_display();
    } else {
      shuffle_stack();
    }
  }
}# End of MAIN LOOP

sub read_remote_display {
  print "Reading remote display info\n";
  my @remote_server;
  if ( -e $remote_display ) {
    open REMOTE_DISPLAY, "<$remote_display" or die;
    @remote_server = <REMOTE_DISPLAY>;
    close REMOTE_DISPLAY;
    $remote_user    = $remote_server[0];
    $remote_pass    = $remote_server[1];
    $remote_server  = $remote_server[2];
    chomp($remote_user);
    chomp($remote_pass);
    chomp($remote_server);
  }
}

sub setup_remote_display {
  header();
  if ( $remote_user =~ /\w/ ) {
    print "\n\nCurrent Config:\n\n";
    print "User:       $remote_user\n";
    print "Password:   $remote_pass\n";
    print "Server:     $remote_server\n\n\n";
  }
  print "\nSetup new remote server info:\n\n";
  print "Are you sure? (y/n)\n\n";
  print_footer();
  my $yesorno = yesorno();
  chomp($yesorno);
  $yesorno=lc($yesorno);
  if ( $yesorno ne 'y' ) { 
    print "Action cancelled.\n";
    sleep 2;
    return;
  }
  header();
  print "Enter new remote user id: ";
  my $remote_user_temp = <STDIN>;
  chomp($remote_user_temp);
  print "\nEnter new remote password: ";
  my $remote_pass_temp = <STDIN>;
  chomp($remote_pass_temp);
  print "\nEnter new server: ";
  my $remote_server_temp = <STDIN>;
  chomp($remote_server_temp);
  print "\n";
  header();
  print "User id:    $remote_user_temp\n";
  print "Password:   $remote_pass_temp\n";
  print "Server:     $remote_server_temp\n\n";
  print "Is this correct? (y/n)\n\n";
  print_footer();
  my $yesorno = yesorno();
  chomp($yesorno);
  $yesorno=lc($yesorno);
  if ( $yesorno ne 'y' ) { 
    print "Action cancelled.\n";
    sleep 2;
    return;
  }
  $remote_user    = $remote_user_temp;
  $remote_pass    = $remote_pass_temp;
  $remote_server  = $remote_server_temp;
  open REMOTE_DISPLAY, ">$remote_display" or die;
  print REMOTE_DISPLAY "$remote_user\n";
  print REMOTE_DISPLAY "$remote_pass\n";
  print REMOTE_DISPLAY "$remote_server";
  close REMOTE_DISPLAY;
}

sub draw_screen {

  open STATUS, ">$status" or warn;

  my $html_header = <<"END_HEADER";

  <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<meta http-equiv="refresh" content="8" >
<head>
<title>Lightning Tourney --by Martin Colello</title>
</head>
<body>
END_HEADER

  print STATUS "$html_header\n";
  print STATUS "<style>\n";
  print STATUS "h3 { color: blue; }\n";
  print STATUS "</style>\n";
  print STATUS "<h3>$event</h3>\n";
  my $print_date = $DATE2;
  $print_date =~ s/_/ /g;
  print STATUS "$print_date<br>\n";
  print STATUS "<pre>\n";

  if ( $tourney_running eq 0 ) { 
    my @number_of_players = keys(%players);
    my $number_of_players = @number_of_players;
    $master_number_of_players = $number_of_players;
  }
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
  if ( $min < 10 ) { $min = "0$min" }
  if ( $sec < 10 ) { $sec = "0$sec" }
  $year = $year + 1900;
  if ( $hour > 12 ) {
    $hour = $hour - 12;
  }

  my @abbr = qw(January February March April May June July August September October November December);
  $DATE = "$hour".':'."$min".":$sec"."_$abbr[$mon]"."_$mday"."_$year";
  $screen_contents = "\n";

  # Count the number of players still alive
  my $number_of_players = 0;
  my @countplayers = keys(%players);
  $number_of_players = @countplayers;

  header();

  print STATUS "\nLightning Chip Tourney             --by Martin Colello\n\n\n";

  my $stack_num = @stack;
  if ( $stack_num < 2 ) {
    print STATUS "<h3>Tournament winner:  $stack[0]</h3>\n\n";
  }

  # Print single column header if 15 players or less
  print color('bold yellow') unless ( $Colors eq 'off');;
  if ( ($master_number_of_players > 0) && ($master_number_of_players < 16) ) {
    print "Player                         Time       Won        Chips      Table \n\n";
    print STATUS "Player                         Time       Won        Chips      Table \n\n";
  }
  # Print double column header if between 19 and 30
  if ( ($master_number_of_players > 15) && ($master_number_of_players < 31) ) {
    print "Player                     Time  Won Chips Table           Player                    Time   Won Chips Table\n\n";
    print STATUS "Player                     Time  Won Chips Table           Player                    Time   Won Chips Table\n\n";
  }
  # Print triple column header if 31 players or more
  if ($master_number_of_players > 30) {
    print "Player       Time   Won Chips Table       Player       Time   Won Chips Table       Player       Time   Won Chips Table\n\n";
    print STATUS "Player       Time   Won Chips Table       Player       Time   Won Chips Table       Player       Time   Won Chips Table\n\n";
  }

  my @players = keys(%players);
  @players = sort(@players);

  if ( $tourney_running eq 0 ) { @stack = @players }

  # Create array which we can sort
  my @display_sort;
  foreach(@players){
    my $player = $_;
    my $chips = $players{$player}{'chips'};
    my $table = $players{$player}{'table'};
    my $won   = $players{$player}{'won'};
    my $time  = $players{$player}{'time'};
    my $line  = "$table:$player:$chips:$won:$time";
    push @display_sort, $line;
  }

  # Sort the array based on table number
  @display_sort = sort { $a <=> $b } (@display_sort);

  # Hold results of final printout to screen
  my @final_display;

  # Add lines WITHOUT table to array in stack order
  foreach(@stack) {
    my $stack_player = $_;
    foreach(@display_sort) {
      my $line = $_;
      my @split  = split /:/, $line;
      my $table  = $split[0];
      my $player = $split[1];
      #my $display_player = substr($player, 0, 24);
      my $display_player = $player;
      my $chips  = $split[2];
      my $won    = $split[3];
      my $time   = " ";
      if ( $table eq 'none' ) { $table = 'In line' }
      my $printit;

      if ( $master_number_of_players < 16 ) {
	if (( $shuffle_mode eq 'on' ) and ( $table eq 'In line' )) { 
          $printit = sprintf ( "%-30.30s %-10.10s %-10.10s %-10.10s %-8.8s\n", "$display_player", "$time", "$won", "$chips", " " );
	} else {
          $printit = sprintf ( "%-30.30s %-10.10s %-10.10s %-10.10s %-8.8s\n", "$display_player", "$time", "$won", "$chips", "$table" );
	}
        if ( $tourney_running eq 0 ) { 
          $printit = sprintf ( "%-30.30s %-10.10s %-10.10s %-10.10s %-8.8s\n", "$display_player", "$time", "$won", "$chips", " " );
        }
        if (( $stack_player eq $player ) and ( $table eq 'In line' )) {
          push @final_display, $printit;
        }
      }  
      if ( ( $master_number_of_players > 15 ) && ( $master_number_of_players < 31 ) )  {
	if (( $shuffle_mode eq 'on' ) and ( $table eq 'In line' )) { 
          $printit = sprintf ( "%-25.25s %-7.7s %-3.3s %-3.3s %-7.7s", "$display_player", "$time", "$won", "$chips", " " );
	} else {
          $printit = sprintf ( "%-25.25s %-7.7s %-3.3s %-3.3s %-7.7s", "$display_player", "$time", "$won", "$chips", "$table" );
	}
        if ( $tourney_running eq 0 ) { 
          $printit = sprintf ( "%-25.25s %-7.7s %-3.3s %-3.3s %-7.7s", "$display_player", "$time", "$won", "$chips", " " );
        }
        if (( $stack_player eq $player ) and ( $table eq 'In line' )) {
          push @final_display, $printit;
        }
      }  
      if ( $master_number_of_players > 30 ) {
	if (( $shuffle_mode eq 'on' ) and ( $table eq 'In line' )) { 
          $printit = sprintf ( "%-12.12s %-6.6s %-3.3s %-5.5s %-7.7s", "$display_player", "$time", "$won", "$chips", " " );
	} else {
          $printit = sprintf ( "%-12.12s %-6.6s %-3.3s %-5.5s %-7.7s", "$display_player", "$time", "$won", "$chips", "$table" );
	}
        if ( $tourney_running eq 0 ) { 
          $printit = sprintf ( "%-12.12s %-6.6s %-3.3s %-5.5s %-7.7s", "$display_player", "$time", "$won", "$chips", " " );
        }
        if (( $stack_player eq $player ) and ( $table eq 'In line' )) {
          push @final_display, $printit;
        }
      }  
    }
  }
  if ( $master_number_of_players < 16 ) {
    my $blank_line = "\n";
    push @final_display, "$blank_line";
  }

  # Add lines WITH table numbers to array
  foreach(@display_sort) {
    my $line = $_;
    my @split  = split /:/, $line;
    my $table  = $split[0];
    my $player = $split[1];
    #my $display_player = substr($player, 0, 24);
    my $display_player = $player;
    my $chips  = $split[2];
    my $won    = $split[3];
    #my $time   = $split[4];
    my $time   = "30";
    my $time_start = $players{$player}{'time_start'};
    my $current_time = time();
    my $time_used = $current_time - $time_start;
    my $time_used_pretty = parse_duration($time_used);
    $time_used_pretty =~ s/^\d\d://g; # Remove hours digits
    $time_used_pretty =~ s/^0//g;     # Remove zero from beginning of time
    my $printit;

    if ( $master_number_of_players < 16 ) {
      if ( $time_start > 0 ) {
        $printit = sprintf ( "%-30.30s %-10.10s %-10.10s %-10.10s %-8.8s\n", "$display_player", "$time_used_pretty", "$won", "$chips", "$table" );
      } else {
        $printit = sprintf ( "%-30.30s %-10.10s %-10.10s %-10.10s %-8.8s\n", "$display_player", " ", "$won", "$chips", "$table" );
      }
      if ( $table !~ /none/ ) {
        push @final_display, $printit;
      }
    }
    if ( ($master_number_of_players > 15) && ($master_number_of_players <  31) ) {
      if ( $time_start > 0 ) {
        $printit = sprintf ( "%-25.25s %-7.7s %-3.3s %-3.3s %-7.7s", "$display_player", "$time_used_pretty", "$won", "$chips", "$table" );
      } else {
        $printit = sprintf ( "%-25.25s %-7.7s %-3.3s %-3.3s %-7.7s", "$display_player", " ", "$won", "$chips", "$table" );
      }
      if ( $table !~ /none/ ) {
        push @final_display, $printit;
      }
    }
    if ($master_number_of_players > 30) {
      if ( $time_start > 0 ) {
        $printit = sprintf ( "%-12.12s %-6.6s %-3.3s %-5.5s %-7.7s", "$display_player", "$time_used_pretty", "$won", "$chips", "$table" );
      } else {
        $printit = sprintf ( "%-12.12s %-6.6s %-3.3s %-5.5s %-7.7s", "$display_player", " ", "$won", "$chips", "$table" );
      }
      if ( $table !~ /none/ ) {
        push @final_display, $printit;
      }
    }
  }

  # Print to screen in correct TABLE order
  my $first_line = 'yes';
  my $color  = 'bold white';
  if ( $master_number_of_players < 16 ) {
    foreach(@final_display) {
      my $line   = $_;
      print color($color) unless ( $Colors eq 'off');;
      if ( $color eq 'bold white'  ) { $color = 'bold cyan' } else { $color = 'bold white' }
      if ($first_line eq 'yes') {
        $line =~ s/In line/Next up/;
        $first_line = 'no';
      }
      if ($shuffle_mode =~ /on/ ) {
        $line =~ s/In line/ /;
        $line =~ s/Next up/ /;
      }
      print "$line";
      print STATUS "$line";
      $screen_contents .= $line;
    }
  }
  if ( ($master_number_of_players > 15) && ($master_number_of_players <  31) ) {
    $final_display[0] =~ s/In line/Next up/;
    if ($shuffle_mode =~ /on/ ) {
      $final_display[0] =~ s/In line/ /;
      $final_display[0] =~ s/Next up/ /;
    }
    my $color = 'bold cyan';
    print color($color) unless ( $Colors eq 'off');;
    print columnize(\@final_display,{displaywidth=>120,colsep=>'          '});
    print STATUS columnize(\@final_display,{displaywidth=>120,colsep=>'          '});
  }
  if ($master_number_of_players > 30) {
    $final_display[0] =~ s/In line/Next up/;
    if ($shuffle_mode =~ /on/ ) {
      $final_display[0] =~ s/In line/ /;
      $final_display[0] =~ s/Next up/ /;
    }
    my $color = 'bold cyan';
    print color($color) unless ( $Colors eq 'off');;
    print columnize(\@final_display,{displaywidth=>140,colsep=>'     '});
    print STATUS columnize(\@final_display,{displaywidth=>140,colsep=>'     '});
  }

  print "\n";
  print STATUS "\n";

  # DEAD DISPLAY
   
  my @dead_display;

  #print STATUS "KNOCKED OUT:\n\n";
  print STATUS "<p style=\"color:red\">\n";

  if ( $master_number_of_players < 16 ) {
    # Print to screen the list of dead players in RED font
    foreach(@dead) {
      my $line = $_;
      my @split = split /:/, $line;
      my $deadname = $split[0];
      #my $display_player = substr($deadname, 0, 24);
      my $display_player = $deadname;
      my $deadwon  = $split[1];
      my $color  = 'bold red';
      print color($color) unless ( $Colors eq 'off');
      my $printit = sprintf ( "%-40s %-3s\n", "$display_player", "$deadwon" );
      print "$printit";
      print STATUS "$printit";
      $screen_contents .= $printit;
    }
  }
  if ( ($master_number_of_players > 15) && ($master_number_of_players <  31) ) {
    foreach(@dead) {
      my $line = $_;
      my @split = split /:/, $line;
      my $deadname = $split[0];
      #my $display_player = substr($deadname, 0, 24);
      my $display_player = $deadname;
      my $deadwon  = $split[1];
      my $printit = sprintf ( "%-24.24s %-7.7s %-3.3s %-3.3s %-7.7s", "$display_player", "      ", "$deadwon", " ", " " );
      push @dead_display, "$printit";
      $screen_contents .= $printit;
    }
  }
  if ($master_number_of_players > 30) {
    foreach(@dead) {
      my $line = $_;
      my @split = split /:/, $line;
      my $deadname = $split[0];
      #my $display_player = substr($deadname, 0, 24);
      my $display_player = $deadname;
      my $deadwon  = $split[1];
      my $printit = sprintf ( "%-12.12s %-5.5s %-3.3s %-5.5s %-8.8s", "$display_player", " ", "$deadwon", " ", " " );
      push @dead_display, "$printit";
      $screen_contents .= $printit;
    }
  }
      if (( $master_number_of_players > 15 ) && ($master_number_of_players < 31 )) {
        my $color  = 'bold red';
        print color($color) unless ( $Colors eq 'off');
        if ( exists($dead_display[0]) ) {
          print        columnize(\@dead_display,{displaywidth=>140,colsep=>'           '});
          print STATUS columnize(\@dead_display,{displaywidth=>140,colsep=>'           '});
        }
      }
      if ( $master_number_of_players > 30 ) {
        my $color  = 'bold red';
        print color($color) unless ( $Colors eq 'off');
        if ( exists($dead_display[0]) ) {
          print        columnize(\@dead_display,{displaywidth=>140,colsep=>'     '});
          print STATUS columnize(\@dead_display,{displaywidth=>140,colsep=>'     '});
        }
      }
    print STATUS "</p>\n";
    my $color  = 'bold white';
    print color($color) unless ( $Colors eq 'off');;

    # Display begin tourney message based on number of tables/players added so far
    my @count_the_tables = keys(%tables);
    my $count_the_tables = @count_the_tables;
    if (( $number_of_players < 1 ) and ( $count_the_tables < 1 )) {
      print "Welcome to Lightning Chip Tourney!\n\nTournament is empty.\n\nPlease add at least one table and some players.\n\n";
    }
    if (( $number_of_players < 1 ) and ( $count_the_tables > 0 )) {
      print "Welcome to Lightning Chip Tourney!\n\nTournament is empty.\n\nPlease add some players.\n\n";
    }

  # Print menu
  print "\n\n";
  if ( $tourney_running eq 0 ) {
    my $tables_in_use;
    my @tables_in_use;
    foreach(keys(%tables)) {
      push @tables_in_use, $_;
    }
    @tables_in_use = sort {$a <=> $b } @tables_in_use;
    foreach(@tables_in_use) {
      $tables_in_use = "$tables_in_use,$_";
    }
    if ( $tables_in_use =~ /\w/ ) {
      print color('bold cyan') unless ( $Colors eq 'off');
      $tables_in_use =~ s/^,//g;
      print "Tables numbers in use: $tables_in_use\n\n";
    }
    print color('bold white') unless ( $Colors eq 'off');
    print "(";
    print color('bold yellow') unless ( $Colors eq 'off');
    print "N";
    print color('bold white') unless ( $Colors eq 'off');
    print ")ew player (";
    print color('bold yellow') unless ( $Colors eq 'off');
    print "D";
    print color('bold white') unless ( $Colors eq 'off');
    print ")elete player (";
    print color('bold yellow') unless ( $Colors eq 'off');
    print "A";
    print color('bold white') unless ( $Colors eq 'off');
    print ")dd table      (";
    print color('bold yellow') unless ( $Colors eq 'off');
    print "R";
    print color('bold white') unless ( $Colors eq 'off');
    print ")emove table (";
    print color('bold yellow') unless ( $Colors eq 'off');
    print "C";
    print color('bold white') unless ( $Colors eq 'off');
    print ")olors (";
    print color('bold yellow') unless ( $Colors eq 'off');
    print "S";
    print color('bold white') unless ( $Colors eq 'off');
    print ")etup Remote Display\n(";
    print color('bold yellow') unless ( $Colors eq 'off');
    print "G";
    print color('bold white') unless ( $Colors eq 'off');
    print ")ive chip  (";
    print color('bold yellow') unless ( $Colors eq 'off');
    print "T";
    print color('bold white') unless ( $Colors eq 'off');
    print ")ake chip     (";
    print color('bold yellow') unless ( $Colors eq 'off');
    print "P";
    print color('bold white') unless ( $Colors eq 'off');
    print ")layer from db (";
    print color('bold yellow') unless ( $Colors eq 'off');
    print "Q";
    print color('bold white') unless ( $Colors eq 'off');
    print ")uit program (";
    print color('bold yellow') unless ( $Colors eq 'off');
    print "B";
    print color('bold white') unless ( $Colors eq 'off');
    print ")egin tourney! Ed(";
    print color('bold yellow') unless ( $Colors eq 'off');
    print "i";
    print color('bold white') unless ( $Colors eq 'off');
    print ")t player db\n";
  }
  print_footer() unless ( $tourney_running eq 1 );
  # Print menu
  if ( $tourney_running eq 1 ) {
    #print "(l)oser (n)ew player (d)elete player (r)emove table (a)dd table (g)ive chip (t)ake chip (q)uit program\n";
    print "(";
    print color('bold yellow') unless ( $Colors eq 'off');
    print "L";
    print color('bold white') unless ( $Colors eq 'off');
    print ")oser     (";
    print color('bold yellow') unless ( $Colors eq 'off');
    print "N";
    print color('bold white') unless ( $Colors eq 'off');
    print ")ew player (";
    print color('bold yellow') unless ( $Colors eq 'off');
    print "D";
    print color('bold white') unless ( $Colors eq 'off');
    print ")elete player (";
    print color('bold yellow') unless ( $Colors eq 'off');
    print "A";
    print color('bold white') unless ( $Colors eq 'off');
    print ")dd table (";
    print color('bold yellow') unless ( $Colors eq 'off');
    print "R";
    print color('bold white') unless ( $Colors eq 'off');
    print ")emove table (";
    print color('bold yellow') unless ( $Colors eq 'off');
    print "H";
    print color('bold white') unless ( $Colors eq 'off');
    print ")istory (";
    print color('bold yellow') unless ( $Colors eq 'off');
    print "Q";
    print color('bold white') unless ( $Colors eq 'off');
    print ")uit (";
    print color('bold yellow') unless ( $Colors eq 'off');
    print "U";
    print color('bold white') unless ( $Colors eq 'off');
    print ")undo Pla(";
    print color('bold yellow') unless ( $Colors eq 'off');
    print "Y";
    print color('bold white') unless ( $Colors eq 'off');
    print ")er List\n(";
    print color('bold yellow') unless ( $Colors eq 'off');
    print "G";
    print color('bold white') unless ( $Colors eq 'off');
    print ")ive chip (";
    print color('bold yellow') unless ( $Colors eq 'off');
    print "T";
    print color('bold white') unless ( $Colors eq 'off');
    print ")ake chip  (";
    print color('bold yellow') unless ( $Colors eq 'off');
    print "F";
    print color('bold white') unless ( $Colors eq 'off');
    print ")orfeit       (";
    print color('bold yellow') unless ( $Colors eq 'off');
    print "C";
    print color('bold white') unless ( $Colors eq 'off');
    print ")olors    (";
    print color('bold yellow') unless ( $Colors eq 'off');
    print "M";
    print color('bold white') unless ( $Colors eq 'off');
    print ")ove player  (";
    print color('bold yellow') unless ( $Colors eq 'off');
    print "S";
    print color('bold white') unless ( $Colors eq 'off');
    print ")huffle (";
    print color('bold yellow') unless ( $Colors eq 'off');
    print "E";
    print color('bold white') unless ( $Colors eq 'off');
    if ( $shuffle_mode eq 'off' ) {
      print ")nter shuffle mode \n";
    } else {
      print ")xit shuffle mode \n";
    }

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
    my $ampm = 'AM';
    if ( $hour > 12 ) { 
      $hour = $hour - 12;
      $ampm = 'PM';
    }

    # Fix the single digit minute issue
    if ( $min < 10 ) { $min = "0$min" }
    if ( $sec < 10 ) { $sec = "0$sec" }

    my $TIME = "$hour".':'."$min "."$ampm";

    if ( ( $send ne 'none' ) and ( $shuffle_mode ne 'on' ) ) {
      print color('bold green') unless ( $Colors eq 'off');
      print "$send";
      print color('bold white') unless ( $Colors eq 'off');
    }

    my @count_players = keys(%players);
    my $count_players = @count_players;

    print_footer();

  }

  print STATUS "</pre></body></html>\n";
  close STATUS;
  if ( $tourney_running eq 1 ) {
    send_status_to_server();
  }
}

sub print_footer {

  if ( ( $tourney_running eq 1 ) and ( $Colors eq 'on'  ) and ( $shuffle_mode eq 'on' ) )  {
    print colored("\n       SHUFFLE      SHUFFLE      SHUFFLE      SHUFFLE      SHUFFLE     SHUFFLE     SHUFFLE     SHUFFLE     SHUFFLE       ", 'bright_yellow on_red'), "\n";
  }
  if ( ( $tourney_running eq 1 ) and ( $Colors eq 'on'  ) and ( $shuffle_mode eq 'off' ) and ( $version eq $check_version ) )  {
     print colored("\n    http://lightningchip.xyz for live updates!                                                                           ", 'bright_yellow on_blue'), "\n";
  }
  if ( ( $tourney_running eq 1 ) and ( $Colors eq 'on'  ) and ( $shuffle_mode eq 'off' ) and ( $version ne $check_version ) )  {
     print colored("\n    http://lightningchip.xyz for live updates!               New software version available!                             ", 'bright_yellow on_blue'), "\n";
  }
  if ( ( $tourney_running eq 1 ) and ( $Colors eq 'off' ) and ( $shuffle_mode eq 'on' ) )  {
    print         "\n       SHUFFLE      SHUFFLE      SHUFFLE      SHUFFLE      SHUFFLE     SHUFFLE     SHUFFLE     SHUFFLE     SHUFFLE       \n";
  }
  if ( ( $tourney_running eq 0 ) and ( $Colors eq 'on'  ) )  {
    print colored("\n                                                                                                                         ", 'bright_yellow on_blue'), "\n";
  }
}

sub list_players {

  my @players = keys(%players);
  @players = sort(@players);

  header();

  my $color = 'bold cyan';
  print color($color) unless ( $Colors eq 'off');
  print columnize(\@players,{displaywidth=>120,colsep=>'   '});
  print "\n\n";
  if ( @dead ) {
    my @print_dead;
    foreach(@dead) {
      my $line = $_;
      my @split = split /:/, $line;
      push @print_dead, $split[0];
    }
    my $color = 'bold red';
    print color($color) unless ( $Colors eq 'off');
    print columnize(\@print_dead,{displaywidth=>120,colsep=>'   '});
  }
  my $color = 'bold cyan';
  print color($color) unless ( $Colors eq 'off');
  print "\n\nAny key to continue\n";
  print_footer();
  yesorno('any');
}



sub send_status_to_server {

  my $host = $remote_server;
  if ( $host !~ /\w/ )        { return }
  if ( $remote_user !~ /\w/ ) { return }
  if ( $remote_pass !~ /\w/ ) { return }

  if ( $remote_server_check == 1 ) {
    my $p = Net::Ping->new('tcp');
    $p->port_number(22);
    if ( $p->ping($host,3) ) {
      $remote_server_check = 2;
    } else {
      $remote_server_check = 3;
    }
    $p->close();
  }

  my $remote_filename = "$event".'.html';
  $remote_filename =~ s/\s+/_/g;
  my %args = ( user     => $remote_user,
               password => $remote_pass,
               warn     => 'false',
	       ssh_args => [ port => '22', strict_host_key_checking => 'no',],
	       #debug    => 1,
             );
  if ( $remote_server_check == 2 ) {
    eval { 
      my $sftp = Net::SFTP->new($host,%args);
      $sftp->put("$status", "/var/www/html/results/$remote_filename");
    }
  }
}

sub loser {

  # Take backup of status in case we want to undo
  backup();

  # Actions to take when selecting a loser

  header();
  
  # Get list of players from hash, and sort them
  my @players = keys(%players);
  @players = sort(@players);
  my $count_players = @players;
  
  print "\n\n\n\nPlease choose number of player who lost:\n\n";
  my @active_players;
  foreach(@players) {
    my $player = $_;
    if ( $players{$player}{'table'} ne 'none' ) {
      push @active_players, $player;
    }
  }

  my $count_active_players = @active_players;
  if ( $count_active_players == 0 ) {
    print "\nNo players are at a table.\n";
    sleep 2;
    return;
  }

  my $numselection = print_menu_array(@active_players);  
  if ( $numselection == 1000 ) {
    return;
  }
  my $player = $active_players[$numselection];
  chomp($player);

  if ( $players{$player}{'table'} eq 'none' ) {
    print "Error, this player was not at a table.\n";
    sleep 3;
    return;
  }

    $players{$player}{'chips'}--; # Take a chip from the loser

    # Get table number player lost on
    my $table = $players{$player}{'table'};

    # Set loser's table to 'none'
    $players{$player}{'table'} = 'none';

    # Record who beat who to log file
    my $opponent;
    foreach(@players) {
      my $possible_opponent = $_;

      if ( $table ne 'none' ) {
        if ( $players{$possible_opponent}{'table'} eq $table ) {
          $players{$possible_opponent}{'won'}++;
          my $printit = sprintf ( "%-30s %-10s %-30s\n", "$possible_opponent", 'beat', "$player" );
	  $players{$player}{'time_start'}            = 0;
	  $players{$possible_opponent}{'time_start'} = 0;
	  $opponent = $possible_opponent;
	  push @whobeat, $printit;
	  push @whobeat_csv, "$possible_opponent"."SPLIT"."$player"."SPLIT"."$players{$possible_opponent}{'table'}"."SPLIT"."$players{$possible_opponent}{'fargo_id'}"."SPLIT"."$players{$player}{'fargo_id'}"."SPLIT"."$DATE";
        }	
      }
    }

    # Delete players from tourney if chips are zero
    delete_players();
    $undo_last_loser_count = 0;

    # Assign table to new player if possible
    my @players_count = keys(%players);
    my $number_of_players = @players_count;
    my @tables_count = keys(%tables);
    my $tables_count = @tables_count;
    my $raw_tables_count = @tables_count;
    $tables_count = $tables_count * 2;

    my $extra_players = 'no';

    my $extra_tables_count = 0;
    foreach(@players_count) {
      my $name = $_;
      if ( $players{$name}{'table'} eq 'none' ) {
	$extra_tables_count++;
      } 
    }

    if ( $extra_tables_count > 1 ) {
        $extra_players = 'yes';
    }

    # Delete table from tourney once it's no longer needed.
    if (( $extra_players eq 'no' ) and ( $raw_tables_count > 1 )) {
      my $remove_table = $players{$opponent}{'table'};
      $players{$opponent}{'table'} = 'none';
      header();
      print "\n\n\n\n\n\n\n\n";
      print color('bold red') unless ( $Colors eq 'off');
      print "**************\n";
      print "*** NOTICE ***\n";
      print "**************\n\n";
      print color('bold white') unless ( $Colors eq 'off');
      print "\n\n\nRemoving table $remove_table from tourney.  $opponent gets back in line.\n\nAny key to continue.\n";
      $players{$opponent}{'flip_break'} = 'yes';
      yesorno('any');
      delete $tables{$remove_table};
    }

    if (( $extra_players eq 'yes' ) and ( $shuffle_mode eq 'off' )) {

      foreach(@stack) {
        my $standup = $_;

        if ( $player eq $standup ) { next }

        if ( exists( $players{$standup} ) and ( $players{$standup}{'table'} eq 'none' ) ) { 
          $players{$standup}{'table'} = $table;
          $players{$standup}{'time_start'} = time();
	  $player_standup = $standup;
          header();
	  if ( $players{$standup}{'flip_break'} eq 'yes' ) {
	    $send = "\nFLIP FOR BREAK\n";
	    $players{$standup}{'flip_break'} = 'no'; 
          } else {
	      $send = "\n";
	  }
	  if ( $players{$standup}{'chips'} > 0 ) {
	    $send .= "Send $standup to table $table\n";
          } else {
	    $send .= " \n";
	  }
          last;
        }
      }
    @stack=((grep $_ ne $player, @stack), $player);
    } 
    if ( $number_of_players < 4 ) {
      $shuffle_mode = 'on';
    }
    if ( $shuffle_mode eq 'on' ) {
      $players{$opponent}{'table'} = 'none';
    }

  if ( $count_players eq 2 ) {
    shuffle_stack('yes');
  }

  store \$send,            "$storable_send";
  store \%players,         "$storable_players";
  store \%tables,          "$storable_tables";
  store \@dead,            "$storable_dead";
  store \@stack,           "$storable_stack";
  store \@whobeat,         "$storable_whobeat";
  store \@whobeat_csv,     "$storable_whobeat_csv";
  store \$tourney_running, "$storable_tourney_running";
}

sub undo_last_loser {
  # Undo last loser
  
  print "\nUndo Last Action\n\n";
  print "Are you sure? (y/n)\n";
  my $yesorno = yesorno();
  chomp($yesorno);
  $yesorno=lc($yesorno);
  if ( $yesorno ne 'y' ) { 
    print "Action cancelled.\n";
    sleep 2;
    return;
  }

  if ( $undo_last_loser_count eq 0 ) {
    %players      = %{ dclone \%backup_players};
    %tables       = %{ dclone \%backup_tables};
    @dead         = @{ dclone \@backup_dead};
    @stack        = @{ dclone \@backup_stack};
    @whobeat      = @{ dclone \@backup_whobeat};
    @whobeat_csv  = @{ dclone \@backup_whobeatcsv};
    $shuffle_mode = $shuffle_mode_undo;
    $undo_last_loser_count = 1;
    print "Reverting level one...\n";
    sleep 2;
    $send = $send1;
    return;
  }
  if ( $undo_last_loser_count eq 1 ) {
    %players      = %{ dclone \%backup_players2};
    %tables       = %{ dclone \%backup_tables2};
    @dead         = @{ dclone \@backup_dead2};
    @stack        = @{ dclone \@backup_stack2};
    @whobeat      = @{ dclone \@backup_whobeat2};
    @whobeat_csv  = @{ dclone \@backup_whobeatcsv2};
    $shuffle_mode = $shuffle_mode_undo2;
    $undo_last_loser_count = 2;
    print "Reverting level two...\n";
    sleep 2;
    $send = $send2;
    return;
  }
  if ( $undo_last_loser_count eq 2 ) {
    %players      = %{ dclone \%backup_players3};
    %tables       = %{ dclone \%backup_tables3};
    @dead         = @{ dclone \@backup_dead3};
    @stack        = @{ dclone \@backup_stack3};
    @whobeat      = @{ dclone \@backup_whobeat3};
    @whobeat_csv  = @{ dclone \@backup_whobeatcsv3};
    $shuffle_mode = $shuffle_mode_undo3;
    $undo_last_loser_count = 3;
    print "Reverting level three...\n";
    sleep 2;
    $send = $send3;
    return;
  }
  if ( $undo_last_loser_count eq 3 ) {
    %players      = %{ dclone \%backup_players4};
    %tables       = %{ dclone \%backup_tables4};
    @dead         = @{ dclone \@backup_dead4};
    @stack        = @{ dclone \@backup_stack4};
    @whobeat      = @{ dclone \@backup_whobeat4};
    @whobeat_csv  = @{ dclone \@backup_whobeatcsv4};
    $shuffle_mode = $shuffle_mode_undo4;
    $undo_last_loser_count = 4;
    print "Reverting level four...\n";
    sleep 2;
    $send = $send4;
    return;
  }
  if ( $undo_last_loser_count eq 4 ) {
    %players      = %{ dclone \%backup_players5};
    %tables       = %{ dclone \%backup_tables5};
    @dead         = @{ dclone \@backup_dead5};
    @stack        = @{ dclone \@backup_stack5};
    @whobeat      = @{ dclone \@backup_whobeat5};
    @whobeat_csv  = @{ dclone \@backup_whobeatcsv5};
    $shuffle_mode = $shuffle_mode_undo5;
    $undo_last_loser_count = 5;
    print "Reverting level five...\n";
    sleep 2;
    $send = $send5;
    return;
  }
  if ( $undo_last_loser_count eq 5 ) {
    print "No more undo levels available...\n";
    sleep 2;
    $send = "\n\n";
    return;
  }
}

sub start_tourney {
  header();

  # Count the number of tables
  my @counttables = keys(%tables);
  my $counttables = @counttables;

  # Count number of players
  my @number_of_players = keys(%players);
  my $number_of_players = @number_of_players;
  $master_number_of_players = $number_of_players;

  # Reduce by half because two players per table.
  my $number_of_players = $number_of_players / 2;

  # If no tables added we can't start the tourney
  if ( $counttables eq 0 ) {
    print "No tables added yet.\n";
    sleep 3;
    return;
  }

  if ( $number_of_players <= $counttables ) {
    print "Too many tables are configured to start tourney.\n\n";
    print "Please remove a table.\n\n";
    sleep 5;
    return;
  }


  print "\n\n\n\n$counttables tables have been configured.\n";
  print "\n\n\n\n\n\nStart tourney now? (y/n)\n";
  print_footer();
  my $yesorno = yesorno();
  chomp($yesorno);
  if ( $yesorno eq 'y' ) {
    print "\nRandomizing player order...\n";
    sleep 1;
    $tourney_running = 1;
    my @players = keys(%players);
    @stack = shuffle(@players);

    # Assign two players per table from the stack
    assign();
    restart_backup();# Take backup in case you want to restart entire tourney
  }
}

sub new_table {

  # Take backup of status in case we want to undo
  backup();

  header();
  my @tables = keys(%tables);
  chomp(@tables);
  @tables = sort { $a <=> $b } @tables;

  $color = 'bold white';
  print color($color) unless ( $Colors eq 'off');
  print "Current tables:\n";
  print_array(@tables);

  $color = 'bold white';
  print color($color) unless ( $Colors eq 'off');
  print "\n\nTable Number:\n";
  print color('bold cyan') unless ( $Colors eq 'off');
  chomp(my $name = <STDIN>);
  print color('bold white') unless ( $Colors eq 'off');

  if ( $name !~ /^[+-]?\d+$/ ) {
    print "\nPlease enter only a table number. (No letters allowed.)\n";
    sleep 4;
    return;
  }

  print "Add Table Number $name, correct? (y/n)\n";
  my $yesorno = yesorno();
  chomp($yesorno);
  if ( $yesorno eq 'y' ) {
    if ( exists $tables{$name} ) {
      print "Table $name already exists.\n";
      sleep 3;
      return;
    }
    $tables{$name} = 1;
    # Sort through stack and grab two players that have table set to none
    # Then put them back on bottom of stack
    if ( $tourney_running eq 1 ) {
      foreach (@stack) {
        my $standup = $_;
	if ($players{$standup}{'table'} eq 'none') {
          $players{$standup}{'table'} = $name;
          @stack=((grep $_ ne $standup, @stack), $standup);
	  last;
	}
      }
      foreach (@stack) {
        my $standup = $_;
	if ($players{$standup}{'table'} eq 'none') {
          $players{$standup}{'table'} = $name;
          @stack=((grep $_ ne $standup, @stack), $standup);
	  last;
	}
      }
    }
  } else {
    return
  } 
}

sub new_player {

  # Take backup of status in case we want to undo
  backup();

  header();

  my %fargo_id;
  my $potential_fargo_id = 0;
  my @fargo_storage;
  if ( -e $fargo_storage_file ) {
    open (FARGO, '<',$fargo_storage_file);
    @fargo_storage = <FARGO>;
    close FARGO;
  }

  my @player_db;
  if ( -e $player_db ) {
    open (PLAYER_DB, '<',$player_db);
    @player_db = <PLAYER_DB>;
    close PLAYER_DB;
  }

  chomp(@fargo_storage);
  chomp(@player_db);

  foreach(@fargo_storage) {
    my $line = $_;
    my @split = split /:/, $line;
    $fargo_id{$split[0]} = $split[1];
  }

  print "Player Name:\n";
  print color('bold cyan') unless ( $Colors eq 'off');
  chomp(my $name = <STDIN>);
  $name =~ s/\// /g;
  $name =~ s/:/ /g;
  $name =~ s/\%/ /g;
  $name =~ s/\*/ /g;
  $name =~ s/\&/ /g;
  $name =~ s/\^/ /g;
  $name =~ s/\s+/ /g;
  $name =~ s/([\w']+)/\u\L$1/g;#Capitalize first letter of each word
  print color('bold white') unless ( $Colors eq 'off');

  print "Fargo Rating:\n";
  print color('bold cyan') unless ( $Colors eq 'off');
  chomp(my $fargo = <STDIN>);
  print color('bold white') unless ( $Colors eq 'off');
  if ( $fargo !~ /^\d+\z/ ) {
    $fargo = 100;
  }

  my $name_lower = lc($name);
  my $name_db = $name;


  $name = "$name ($fargo)";

  if ( exists($players{$name}) ) {
    print "Player already exists.\n";
    sleep 3;
    return;
  }

  if ( exists($fargo_id{$name_lower}) ) {
    $potential_fargo_id = $fargo_id{$name_lower};
  }

  #  if ( $potential_fargo_id == 0 ) {
  #  print "Fargo ID Number: (or just just hit Enter for blank)\n";
  #} else {
  #  print "Fargo ID Number [$potential_fargo_id]:\n";
  #}
  #print color('bold cyan') unless ( $Colors eq 'off');
  #chomp(my $fargo_id = <STDIN>);
  #if (( $potential_fargo_id > 1 ) and ( $fargo_id eq "" )) {
  #  $fargo_id = $potential_fargo_id;
  #}

  my $fargo_id;

  print color('bold white') unless ( $Colors eq 'off');
  if ( $fargo_id !~ /^\d+\z/ ) {
    $fargo_id = 0;
  }
  my $fargo_length = length($fargo_id);

  my @fargo_id_keys = keys(%players);
  chomp(@fargo_id_keys);
  foreach(@fargo_id_keys) {
    my $key = $_;
    if (( $players{$key}{'fargo_id'} eq $fargo_id ) and ( $fargo_length > 2 )) {
      print "This Fargo ID has already been used.\n";
      sleep 3;
      return;
    } 
  }

  my $potential_chips = get_start_chips($fargo);

  print "Number of chips [$potential_chips]:\n";
  print color('bold cyan') unless ( $Colors eq 'off');
  chomp(my $chips = <STDIN>);
  if (( $potential_chips > 1 ) and ( $chips eq "" )) {
    $chips = $potential_chips;
  }
  print color('bold white') unless ( $Colors eq 'off');
  if ( $chips !~ /^\d+\z/ ) {
    print "Chips must be a number.\n";
    sleep 3;
    return;
  }
  if ( $chips < 1 ) {
    print "Chips must be more than zero.\n";
    sleep 3;
    return;
  }

  print "$name with $chips chips, correct? (y/n)\n";

  if ( ($name_lower =~ /colello/) && ($name_lower =~ /mart/) ) {
    $name = "Vince Colello ($fargo)";
  }
  print_footer();
  my $yesorno = yesorno();
  chomp($yesorno);
  if ( $yesorno eq 'y' ) {
    $players{$name}{'chips'}    = $chips;
    $players{$name}{'table'}    = 'none';
    $players{$name}{'fargo'}    = $fargo;
    $players{$name}{'fargo_id'} = $fargo_id;
    $players{$name}{'won'}      = 0;
    my $player_db_line = "$name_db:$fargo_id";
    push @player_db, $player_db_line;

    # If tourney is already started, put new player at the top of the stack
    if ( $tourney_running eq 1 ) {
      unshift @stack, $name;
    }

    # Write out new fargo keys file
    $fargo_id{$name_lower} = $fargo_id;
    open (OUT, '>',$fargo_storage_file);
    my @fargo_id_keys = keys(%fargo_id);
    @fargo_id_keys = sort(@fargo_id_keys);
    foreach(@fargo_id_keys){
      my $key = $_;
      print OUT "$key:$fargo_id{$key}\n";
    }
    
    # Write out new player databases file
    $fargo_id{$name_lower} = $fargo_id;
    open (OUT, '>',$player_db);
    foreach(@player_db){
      my $line = $_;
      if ( $line =~ /^\s/ ) { next }
      if ( $line !~ /^\w/ ) { next }
      $line =~ s/([\w']+)/\u\L$1/g;#Capitalize first letter of each word
      print OUT "$line\n";
    }
    close OUT;
  } 
}

sub new_player_from_db {
  header();

  # Take backup of status in case we want to undo
  backup();

  # If db file does not exist, exit subroutine.
  if ( ! -e $player_db ) { 
    print "No db yet.\n";
    sleep 1;
    return;
  }

  open (DB, '<',$player_db) or return;
  chomp(my @db = <DB>);
  close DB;

  @db = sort(@db);

  my @unique = do { my %seen; grep { !$seen{$_}++ } @db };

  @db = @unique;

  $color = 'bold white';
  print color($color) unless ( $Colors eq 'off');
  print "\nPlease choose number of player to add\n\n";
  my $numselection = print_menu_array_columns(@db);
  if ( $numselection == 1000 ) {
    return;
  }

  my $line     = $db[$numselection];
  my @split    = split /:/, $line;
  my $name     = $split[0];
  $name =~ s/([\w']+)/\u\L$1/g;#Capitalize first letter of each word
  my $fargo_id = $split[1];

  print "Fargo Rating:\n";
  print color('bold cyan') unless ( $Colors eq 'off');
  chomp(my $fargo = <STDIN>);
  print color('bold white') unless ( $Colors eq 'off');
  if ( $fargo !~ /^\d+\z/ ) {
    $fargo = 100;
  }

  $name = "$name ($fargo)";
  if ( exists($players{$name}) ) {
    print "Player already exists.\n";
    sleep 3;
    return;
  }

  my $potential_chips = get_start_chips($fargo);

  print "Number of chips [$potential_chips]:\n";
  print color('bold cyan') unless ( $Colors eq 'off');
  chomp(my $chips = <STDIN>);
  if (( $potential_chips > 1 ) and ( $chips eq "" )) {
    $chips = $potential_chips;
  }
  print color('bold white') unless ( $Colors eq 'off');
  if ( $chips !~ /^\d+\z/ ) {
    print "Chips must be a number.\n";
    sleep 3;
    return;
  }
  if ( $chips < 1 ) {
    print "Chips must be more than zero.\n";
    sleep 3;
    return;
  }
  $players{$name}{'chips'}    = $chips;
  $players{$name}{'table'}    = 'none';
  $players{$name}{'fargo'}    = $fargo;
  $players{$name}{'fargo_id'} = $fargo_id;
  $players{$name}{'won'}      = 0;

  # If tourney is already started, put new player at the top of the stack
  if ( $tourney_running eq 1 ) {
    unshift @stack, $name;
  }
  open (DB, '>',$player_db) or return;
  foreach(@db){
    print DB "$_\n";
  }
}
    

sub delete_player {

  # Take backup of status in case we want to undo
  backup();

  header();

  my @players = keys(%players);
  @players = sort(@players);

  $color = 'bold white';
  print color($color) unless ( $Colors eq 'off');
  print "\nPlease choose number of player to delete:\n\n";
  my $numselection = print_menu_array(@players);
  if ( $numselection == 1000 ) {
    return;
  }

  my $player = $players[$numselection];
  chomp($player);

  if ( $players{$player}{'table'} ne 'none' ) { 
    print "Cannot delete player who is at a table.\n";
    sleep 3;
    return;
  }  

  print "THIS WILL REMOVE PLAYER FROM TOURNEY\n";
  print "Delete $player, correct? (y/n)\n";
  my $yesorno = yesorno();
  chomp($yesorno);
  if ( $yesorno eq 'y' ) {
    delete $players{$player}{'chips'};
    delete $players{$player}{'table'};
    delete $players{$player}{'won'};
    delete $players{$player}{'fargo_id'};
    delete $players{$player};
    # Delete player from stack
    my @new_stack;
    foreach(@stack) {
      my $line = $_;
      if ( $player eq $line ) { 
        next;
      }
      push @new_stack, $line;
    }
    @stack = @new_stack;
    return;
  } else {
    return
  } 
}

sub give_chip {

  # Take backup of status in case we want to undo
  backup();

  my @players = keys(%players);
  @players = sort(@players);

  $color = 'bold white';
  print color($color) unless ( $Colors eq 'off');
  header();
  print "\nPlease choose number of player to give chip:\n\n";
  my $numselection = print_menu_array(@players);

  if ( $numselection == 1000 ) {
    return;
  }
  
  my $player = $players[$numselection];
  chomp($player);

  print "Grant chip to $player, correct? (y/n)\n";
  my $yesorno = yesorno();
  chomp($yesorno);
  if ( $yesorno eq 'y' ) {
    $players{$player}{'chips'} = $players{$player}{'chips'} + 1;
    return;
  } else {
    return
  } 
}

sub take_chip {

  # Take backup of status in case we want to undo
  backup();

  my @players = keys(%players);
  @players = sort(@players);

  header();
  $color = 'bold white';
  print color($color) unless ( $Colors eq 'off');
  print "\nPlease choose number of player to take chip:\n\n";
  my $numselection = print_menu_array(@players);

  if ( $numselection == 1000 ) {
    return;
  }
  
  my $player = $players[$numselection];
  chomp($player);
  if ( $players{$player}{'chips'} < 2 ) {
    print "Cannot take last chip from player.\n";
    sleep 3;
    return;
  }

  print "Take chip from $player, correct? (y/n)\n";
  my $yesorno = yesorno();
  chomp($yesorno);
  if ( $yesorno eq 'y' ) {
    $players{$player}{'chips'} = $players{$player}{'chips'} - 1;
    delete_players();
    return;
  } else {
    return
  } 
}

sub move_player {

  my @players = keys(%players);
  @players = sort(@players);

  header();
  $color = 'bold white';
  print color($color) unless ( $Colors eq 'off');
  print "\nPlease choose number of player to move:\n\n";
  my $numselection = print_menu_array(@players);

  my $player = $players[$numselection];
  chomp($player);

  my @tables = keys(%tables);
  @tables = sort { $a <=> $b } (@tables);
  push @tables, 'none';

  header();
  print "\nMove $player to which table?:\n\n";
  my $numselection = print_menu_array(@tables);

  my $table = $tables[$numselection];
  chomp($table);

  $players{$player}{'table'} = $table;

  return;
}


sub delete_table {

  # Take backup of status in case we want to undo
  backup();

  my @tables = keys(%tables);
  @tables = sort { $a <=> $b } (@tables);

  header();
  print "\nPlease choose number of table to delete:\n\n";
  my $numselection = print_menu_array(@tables);

  if ( $numselection == 1000 ) {
    return;
  }
  
  my $table = $tables[$numselection];
  chomp($table);

  print "Delete table $table, correct? (y/n)\n";
  my $yesorno = yesorno();
  chomp($yesorno);

  # If deleting a table in use move players to top of stack
  if ( $yesorno eq 'y' ) {
    delete $tables{$table};
    my @players = keys(%players);
    # Reverse sort players so that they are added back into stack in alphabetical order.
    @players = reverse sort(@players);
    foreach (@players) {
      my $player = $_;
      if ( $players{$player}{'table'} eq $table ) {
        $players{$player}{'table'} = 'none';
        @stack=((grep $_ ne $player, @stack), $player);
        my $tempplayer = pop @stack;
        unshift @stack, $tempplayer;
      }
    }
    return;
  } else {
    return
  } 
}

sub quit_program {
  header();
  print "\nQuitting will NOT save tourney data!!!\n";
  print "Hit Y to quit, hit R to restart entire tourney.\n";
  my $yesorno = yesorno();
  chomp($yesorno);
  if ( $yesorno eq 'y' ) {
    draw_screen();
    print OUTFILE "$screen_contents\n\n";
    @whobeat = sort(@whobeat);
    foreach(@whobeat) {
      print OUTFILE "$_";
    }
    close OUTFILE;
    print "\nEnd of tourney.\n";
    #if ( $^O =~ /MSWin32/ ) {
    #  system("start notepad.exe \"$desktop\"");
    #}
    if ( $^O =~ /next|darwin/ ) {
      system("open $desktop");
    }
    delete_storable();
    exit;
  } elsif ( $yesorno eq 'r' ) {
	restart();
  } else {
    return
  } 
}

sub yesorno {
  my $any = shift;
  #if ( $any ne 'any' ) {print "(y/n)\n"}
  my $done = 0;
  my $choice;
  ReadMode 4;
  undef($key);
  while ( !$done ) {
    if ( defined( $key = ReadKey(-1) ) ) {
      $choice = uc ( $key);
      $done = 1 if $choice eq 'Y';
      $done = 1 if $choice eq 'N';
      $done = 1 if $choice eq 'R';
      $done = 1 if $choice eq 'S';
      $done = 1 if $any eq 'any';
    }
  }
  ReadMode 0;
  if ( $choice eq 'Y' ) { return 'y' }
  if ( $choice eq 'N' ) { return 'n' }
  if ( $choice eq 'R' ) { return 'r' }
  if ( $choice eq 'S' ) { return 's' }
}

sub clear_screen {
  if ( $^O =~ /MSWin/             ) { system("cls"    ) }
  if ( $^O =~ /next|darwin|linux/ ) { system("clear"  ) }
}

sub shuffle_stack {
  my $skip_yes = shift;
  header();
  my $check_if_auto=shift;
  my $yesorno;
  if (( $check_if_auto !~ /AUTO/ ) && ( $skip_yes ne 'yes' )) {
    print "\n\n\n\n\nThis will reshuffle ALL players including at current tables!!!\n";
    print "Are you sure? (y/n)\n";
    $yesorno = yesorno();
    chomp($yesorno);
  } else {
    $yesorno = 'y';
  }
  if ( $yesorno eq 'y' ) {
    @stack = keys(%players);
    @stack = shuffle(@stack);

    # Reset all players to table 'none'
    foreach(@stack) {
      my $stackplayer = $_;
      $players{$stackplayer}{'table'} = 'none';
    }

    # Assign two players per table from the stack
    assign();

    if ( $check_if_auto ne 'AUTO' ) {
      print "Shuffled.\n";
      select undef, undef, undef, 0.5;
      #sleep 1;
    }
  }
}

sub delete_players {
  my @players = keys(%players);
  @players = sort(@players);
  foreach(@players){
    my $player = $_;
    if ( ($players{$player}{'chips'} eq 0) or ($player !~ /\w/) ) {
      if ( $^O =~ /MSWin32/ ) {
        Win32::Sound::Play("loser.wav");
      }
      # Add player to dead player array
      push @dead, "$player: $players{$player}{'won'}" unless ( $player !~ /\w/ );

      # Delete the player
      $undo_chips=$players{$player}{'chips'};
      delete $players{$player}{'chips'};
      delete $players{$player}{'table'};
      $undo_won=$players{$player}{'won'};
      delete $players{$player}{'won'};
      $undo_fargo_id=$players{$player}{'fargo_id'};
      delete $players{$player}{'fargo_id'};
      # Delete player from stack
      my @new_stack;
      foreach(@stack) {
        my $line = $_;
        if ( $player eq $line ) {
          next;
        }
        push @new_stack, $line;
      }
      @stack = @new_stack;     
      delete $players{$player};
      }
  }
}

sub assign {
  my $time_start    = time();
  my @tables        = keys(%tables);
  my @players       = keys(%players);
  my $count_tables  = @tables;
  $count_tables     = $count_tables * 2;
  my $count_players = @players;
  if ( $count_players % 2 == 1 ) {
    $count_players = $count_players - 1;
  }
  my $counter = 0;
  foreach(@tables) {
    my $table = $_;
    $counter++;
    if (( $counter <= $count_players ) and ( $counter <= $count_tables )) {
      my $player1 = shift(@stack);
      push @stack, $player1;
      $players{$player1}{'table'} = "$table";
      $players{$player1}{'time_start'} = $time_start;
    }
    $counter++;
    if (( $counter <= $count_players ) and ( $counter <= $count_tables )) {
      my $player2 = shift(@stack);
      push @stack, $player2;
      $players{$player2}{'table'} = "$table";
    }
  }
}

sub header {
  clear_screen();
  # Count the number of players still alive
  my $number_of_players = 0;
  my @countplayers = keys(%players);
  $number_of_players = @countplayers;

  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();

  if ( $min < 10 ) { $min = "0$min" }
  if ( $sec < 10 ) { $sec = "0$sec" }

  my $ampm = 'AM';
  if ( $hour > 12 ) { 
    $hour = $hour - 12;
    $ampm = 'PM';
  }
  my $TIME = "$hour".':'."$min "."$ampm";

  my @players = keys(%players);
  my $count_players = @players;

  if ( $shuffle_mode eq 'off' ) {
    if ( $Colors eq 'on' ) { 
      print colored("\nLIGHTNING CHIP TOURNEY $version           Players: $number_of_players        $TIME                                 --by Martin Colello    ", 'bright_yellow on_blue'), "\n\n\n";
    } elsif ( $Colors eq 'off' ) {
      print         "\nLIGHTNING CHIP TOURNEY $version           Players: $number_of_players        $TIME                                 --by Martin Colello\n\n\n";
    }
  } else {
    if ( $Colors eq 'on' ) { 
      print colored("\nLIGHTNING CHIP TOURNEY $version  SHUFFLE  Players: $number_of_players        $TIME                                 --by Martin Colello    ", 'bright_yellow on_red'), "\n\n\n";
    } elsif ( $Colors eq 'off' ) {
      print         "\nLIGHTNING CHIP TOURNEY $version  SHUFFLE  Players: $number_of_players        $TIME                                 --by Martin Colello\n\n\n";
    }
  }

  print color('bold white') unless ( $Colors eq 'off');
}

sub print_array {
  my @array = @_;
  $color = 'bold white';
  print color($color) unless ( $Colors eq 'off');

  foreach(@array) {
    print "$_\n";
    if ( $color eq 'bold white'  ) { $color = 'bold cyan' } else { $color = 'bold white' }
    print color($color) unless ( $Colors eq 'off');
  }
}

sub print_menu_array {
  my @array = @_;
  my $num = 0;
  foreach(@array) {
    my $choice = $_;
    $num++;
    if ( $color eq 'bold white'  ) { $color = 'bold cyan' } else { $color = 'bold white' }
    print color($color) unless ( $Colors eq 'off');
    print "$num: $choice\n";
  }
  print "\n";
  $color = 'bold white';
  print color($color) unless ( $Colors eq 'off');
  my $numselection = <STDIN>;
  chomp($numselection);
  if ( $numselection !~ /\d/) {
    print "Needed to enter a number, exiting...\n";
    sleep 1;
    return 1000;
  }

  if ( ($numselection > $num) or ($numselection == 0) ) {
    print "Invalid selection, exiting...\n";
    sleep 1;
    return 1000;
  }

  $numselection--;
  return $numselection;
}

# Ugly hacky, but you need more data on the screen at once
sub print_menu_array_columns {
  my @array = @_;
  my $num = 0;
  my @display;
  while (1){
    if (@array) {
      my $one;
      my $two;
      my $three;
      my $four;
      $num++;
      $one = shift(@array);
      $one = sprintf ( "%-4s %-1s %-24s", "$num", "- ","$one" );
      if (@array) {
        $two = shift(@array);
        $num++;
        $two = sprintf ( "%-4s %-1s %-24s", "$num", "- ","$two" );
      }
      if (@array) {
        $three = shift(@array);
        $num++;
        $three = sprintf ( "%-4s %-1s %-24s", "$num", "- ","$three" );
      }
      if (@array) {
        $four = shift(@array);
        $num++;
        $four = sprintf ( "%-4s %-1s %-24s", "$num", "- ","$four" );
      }
      $one   =~ s/:.*//g;
      $two   =~ s/:.*//g;
      $three =~ s/:.*//g;
      $four  =~ s/:.*//g;
      my $printit = sprintf ( "%-30.30s %-30.30s %-30.30s %-30.30s", "$one", "$two", "$three","$four" );
      push @display,"$printit";
    } else {
      last;
    }
  }

  my $num_display = 0;
  foreach(@display) {
    $num_display++;
    if ( $num_display % 28 == 0 ) {
      print "Hit ENTER to continue.\n";
      my $continue = <STDIN>;
    }
    print "$_\n";
  }

  print "\n";
  print "Enter number of selection: ";
  $color = 'bold white';
  print color($color) unless ( $Colors eq 'off');
  my $numselection = <STDIN>;
  chomp($numselection);
  if ( $numselection !~ /\d/) {
    print "Needed to enter a number, exiting...\n";
    sleep 1;
    return 1000;
  }

  if ( ($numselection > $num) or ($numselection == 0) ) {
    print "Invalid selection, exiting...\n";
    sleep 1;
    return 1000;
  }

  $numselection--;
  return $numselection;
}

sub switch_colors {
  if ( $Colors eq 'on' ) { 
    $Colors = 'off';
  } elsif ( $Colors eq 'off' ) {
    $Colors = 'on';
  }
  return;
}

sub game_and_event {
 
  header();
  if ( -f $storable_send ) { 
    print "(R)estore previous tournament or (S)tart new tournament? (R/S)\n";
    my $yesorno = yesorno();
    if ( $yesorno =~ /r/ ) {
      print "Restoring previous tournament.\n";
      sleep 2;
      $send            = ${retrieve("$storable_send")};
      %players         = %{retrieve("$storable_players")};
      %tables          = %{retrieve("$storable_tables")};
      @dead            = @{retrieve("$storable_dead")};
      @stack           = @{retrieve("$storable_stack")};
      @whobeat         = @{retrieve("$storable_whobeat")};
      @whobeat_csv     = @{retrieve("$storable_whobeat_csv")};
      $tourney_running = ${retrieve("$storable_tourney_running")};
      return;
    }
  }

  my $example_name;

  while(1){
    header();
    if ( $tourney_name =~ /\w/ ) {
      $example_name = $tourney_name;
    } else {
      $example_name = 'The Colello Classic';
    }
    print "Please enter Event Name or hit Enter for \"$example_name\":\n";
    print color('bold cyan') unless ( $Colors eq 'off');
    chomp($event = <STDIN>);
    if ($event =~ /\w/ ) {
      last;
    } else {
      $event = $example_name;
      last;
    } 
  }

  chomp($event);
  $event =~ s/\'//g;
  $event =~ s/\://g;

  open (TOURNEYNAME, '>',$tournament_name);
  print TOURNEYNAME "$event";
  close TOURNEYNAME;

  print color('bold white') unless ( $Colors eq 'off');
  print "\n\nPlease enter game type or hit Enter for \"Nine Ball\":\n";
  print color('bold cyan') unless ( $Colors eq 'off');
  chomp($game = <STDIN>);
  if ( $game !~ /\w/ ) { $game = 'Nine Ball' }
  print color('bold white') unless ( $Colors eq 'off');
  chomp($game);

  my @chip_rating_storage;
  if ( -e $chip_rating_storage_file ) {
    open (CHIP, '<',$chip_rating_storage_file);
    @chip_rating_storage = <CHIP>;
    close CHIP;
    $chips_8 = shift(@chip_rating_storage);
    $chips_7 = shift(@chip_rating_storage);
    $chips_6 = shift(@chip_rating_storage);
    $chips_5 = shift(@chip_rating_storage);
    $chips_4 = shift(@chip_rating_storage);
  }

  my $display8 = $chips_8 - 1;
  my $display7 = $chips_7 - 1;
  my $display6 = $chips_6 - 1;
  my $display5 = $chips_5 - 1;
  my $display4 = $chips_4 - 1;

  header();
  print "\n";
  print "FARGO SETUP\n\n";
  print "Simply hit enter for each level if you wish to use default settings.\n\n";
  print "Fargo score for eight chips   [$display8]:\n";
  print color('bold cyan') unless ( $Colors eq 'off');
  chomp(my $chips_enter_8 = <STDIN>);
  if ( $chips_enter_8 =~ /^\d+$/ ) {$chips_8 = $chips_enter_8 + 1}
  print color('bold white') unless ( $Colors eq 'off');

  print "Fargo score for seven chips   [$display7]:\n";
  print color('bold cyan') unless ( $Colors eq 'off');
  chomp(my $chips_enter_7 = <STDIN>);
  if ( $chips_enter_7 =~ /^\d+$/ ) {$chips_7 = $chips_enter_7 + 1}
  print color('bold white') unless ( $Colors eq 'off');

  print "Fargo score for six chips     [$display6]:\n";
  print color('bold cyan') unless ( $Colors eq 'off');
  chomp(my $chips_enter_6 = <STDIN>);
  if ( $chips_enter_6 =~ /^\d+$/ ) {$chips_6 = $chips_enter_6 + 1}
  print color('bold white') unless ( $Colors eq 'off');

  print "Fargo score for five chips    [$display5]:\n";
  print color('bold cyan') unless ( $Colors eq 'off');
  chomp(my $chips_enter_5 = <STDIN>);
  if ( $chips_enter_5 =~ /^\d+$/ ) {$chips_5 = $chips_enter_5 + 1}
  print color('bold white') unless ( $Colors eq 'off');

  print "Fargo score for four chips    [$display4]:\n";
  print color('bold cyan') unless ( $Colors eq 'off');
  chomp(my $chips_enter_4 = <STDIN>);
  if ( $chips_enter_4 =~ /^\d+$/ ) {$chips_4 = $chips_enter_4 + 1}
  print color('bold white') unless ( $Colors eq 'off');

  chomp($chips_8);
  chomp($chips_7);
  chomp($chips_6);
  chomp($chips_5);
  chomp($chips_4);
  open (CHIP, '>',$chip_rating_storage_file) or return;
  print CHIP "$chips_8\n";
  print CHIP "$chips_7\n";
  print CHIP "$chips_6\n";
  print CHIP "$chips_5\n";
  print CHIP "$chips_4";
  close CHIP;
}

sub enter_shuffle_mode {
  header();
  if ( $shuffle_mode eq 'off' ) {
    print "\n\n\n\n\nThis will enter shuffle mode.  In this mode all games need to be completed before\nyou shuffle and start the next round.\n\n";
  } else {
    print "\n\n\n\n\nThis will EXIT shuffle mode.\n\n";
  }
  print "Are you sure? (y/n)\n";
  my $yesorno = yesorno();
  chomp($yesorno);
  if ( $yesorno eq 'y' ) {
    if ( $shuffle_mode eq 'on' ) { 
      $shuffle_mode = 'off';
      $send = "\n";
    } elsif ( $shuffle_mode eq 'off' ) {
      $shuffle_mode = 'on';
    }
  }
}

sub history {
  #header();
  print "Opening history file...\n";
  open (OUTCSV, '>',$outfile_csv);
  print OUTCSV "Player #1,,,Player #2,\n";
  print OUTCSV "Fargo ID,Player Name,Score,Fargo ID,Player Name,Score,Date,Game,Table,Event\n";

  foreach(@whobeat_csv) {
    my $line       = $_;
    my @split      = split /SPLIT/, $line;
    my $winner     = $split[0];
    my $loser      = $split[1];
    my $table      = $split[2];
    my $winner_id  = $split[3];
    my $loser_id   = $split[4];
    my $date_lost  = $split[5];

    if ( $winner =~ /Vince Colello/ ) { $winner = 'Martin Colello' }
    if ( $loser  =~ /Vince Colello/ ) { $loser  = 'Martin Colello' }

    print OUTCSV "$winner_id,$winner,1,$loser_id,$loser,0,$date_lost,$game,$table,$event\n";
  }

  close OUTCSV;

  open( TABFILE, "$outfile_csv" ) or die "$outfile_csv : $!";
 
  my $workbook  = Excel::Writer::XLSX->new( $outfile_xlsx );
  my $worksheet = $workbook->add_worksheet();
 
  # Row and column are zero indexed
  my $row = 0;
 
  while ( <TABFILE> ) {
    chomp;
 
    # Split on single tab
    my @fields = split( ',', $_ );
 
    my $col = 0;
    for my $token ( @fields ) {
        $worksheet->write( $row, $col, $token );
        $col++;
    }
    $row++;
  }
 
  $workbook->close();

  # Open log file
  #if ( $^O =~ /MSWin32/     ) { system ("\"$outfile_csv\"") }
  if ( $^O =~ /MSWin32/     ) { system (1,"\"$outfile_xlsx\"") }
  if ( $^O =~ /next|darwin/ ) { system("open $outfile_csv") }
}

sub get_start_chips {
  my $fargo = shift;
  my $chips = 3;
  if ( $fargo < $chips_4 ) { $chips = 4};
  if ( $fargo < $chips_5 ) { $chips = 5};
  if ( $fargo < $chips_6 ) { $chips = 6};
  if ( $fargo < $chips_7 ) { $chips = 7};
  if ( $fargo < $chips_8 ) { $chips = 8};
  return $chips;
}

sub edit_player_db {
  print color('bold green') unless ( $Colors eq 'off');
  print "\n\nOpening player database...\n";
  print color('bold white') unless ( $Colors eq 'off');
  sleep 3;
  if ( $^O =~ /MSWin32/     ) { system("start notepad.exe \"$player_db\"") }
  if ( $^O =~ /next|darwin/ ) { system("open $player_db") }
}

sub forfeit {

  # Take backup of status in case we want to undo
  backup();

  my @players = keys(%players);
  @players = sort(@players);

  header();
  $color = 'bold white';
  print color($color) unless ( $Colors eq 'off');
  print "\nPlease choose number of player who wishes to forfeit:\n\n";
  my $numselection = print_menu_array(@players);

  if ( $numselection == 1000 ) {
    return;
  }
  
  my $player = $players[$numselection];
  chomp($player);

  print "Player $player will FORFEIT, correct? (y/n)\n";
  my $yesorno = yesorno();
  chomp($yesorno);
  if ( $yesorno eq 'y' ) {
    $players{$player}{'chips'} = 0;
    delete_players();
    return;
  } else {
    return
  } 
}

sub backup {
  # Take backup of status in case we want to undo
  $shuffle_mode_undo5 = $shuffle_mode_undo4;
  $send5 = $send4;
  %backup_players5    = %{ dclone \%backup_players4 };
  %backup_tables5     = %{ dclone \%backup_tables4 };
  @backup_dead5       = @{ dclone \@backup_dead4};
  @backup_stack5      = @{ dclone \@backup_stack4};
  @backup_whobeat5    = @{ dclone \@backup_whobeat4};
  @backup_whobeatcsv5 = @{ dclone \@backup_whobeatcsv4};

  $shuffle_mode_undo4 = $shuffle_mode_undo3;
  $send4 = $send3;
  %backup_players4    = %{ dclone \%backup_players3 };
  %backup_tables4     = %{ dclone \%backup_tables3 };
  @backup_dead4       = @{ dclone \@backup_dead3};
  @backup_stack4      = @{ dclone \@backup_stack3};
  @backup_whobeat4    = @{ dclone \@backup_whobeat3};
  @backup_whobeatcsv4 = @{ dclone \@backup_whobeatcsv3};
  
  $shuffle_mode_undo3 = $shuffle_mode_undo2;
  $send3 = $send2;
  %backup_players3    = %{ dclone \%backup_players2 };
  %backup_tables3     = %{ dclone \%backup_tables2 };
  @backup_dead3       = @{ dclone \@backup_dead2};
  @backup_stack3      = @{ dclone \@backup_stack2};
  @backup_whobeat3    = @{ dclone \@backup_whobeat2};
  @backup_whobeatcsv3 = @{ dclone \@backup_whobeatcsv2};

  $shuffle_mode_undo2 = $shuffle_mode_undo;
  $send2 = $send1;
  %backup_players2    = %{ dclone \%backup_players };
  %backup_tables2     = %{ dclone \%backup_tables };
  @backup_dead2       = @{ dclone \@backup_dead};
  @backup_stack2      = @{ dclone \@backup_stack};
  @backup_whobeat2    = @{ dclone \@backup_whobeat};
  @backup_whobeatcsv2 = @{ dclone \@backup_whobeatcsv};

  $shuffle_mode_undo  = $shuffle_mode;
  $send1 = $send;
  %backup_players     = %{ dclone \%players };
  %backup_tables      = %{ dclone \%tables };
  @backup_dead        = @{ dclone \@dead};
  @backup_stack       = @{ dclone \@stack};
  @backup_whobeat     = @{ dclone \@whobeat};
  @backup_whobeatcsv  = @{ dclone \@whobeat_csv};

}

sub restart_backup {
  # Backup variables in case you want to restart tourney
  $shuffle_mode_restart      = $shuffle_mode;
  $send_restart              = $send;
  %backup_players_restart    = %{ dclone \%players };
  %backup_tables_restart     = %{ dclone \%tables };
  @backup_dead_restart       = @{ dclone \@dead};
  @backup_stack_restart      = @{ dclone \@stack};
  @backup_whobeat_restart    = @{ dclone \@whobeat};
  @backup_whobeatcsv_restart = @{ dclone \@whobeat_csv};
}

sub restart {
  # Restart entire tourney
  
  print "\nRestart ENTIRE tourney!\n\n";
  print "Are you sure? (y/n)\n";
  my $yesorno = yesorno();
  chomp($yesorno);
  $yesorno=lc($yesorno);
  if ( $yesorno ne 'y' ) { 
    print "Action cancelled.\n";
    sleep 2;
    return;
  }

  %players      = %{ dclone \%backup_players_restart};
  %tables       = %{ dclone \%backup_tables_restart};
  @dead         = @{ dclone \@backup_dead_restart};
  @stack        = @{ dclone \@backup_stack_restart};
  @whobeat      = @{ dclone \@backup_whobeat_restart};
  @whobeat_csv  = @{ dclone \@backup_whobeatcsv_restart};
  $shuffle_mode = $shuffle_mode_restart;
  $send = $send_restart;
  shuffle_stack('yes');
  print "\n\nTourney restarted.\n\n";
  sleep 2;
  return;
}

sub parse_duration {
    use integer;
    sprintf("%02d:%02d:%02d", $_[0]/3600, $_[0]/60%60, $_[0]%60);
}

sub delete_storable {

  # Delete recovery files
  unlink("$storable_send");
  unlink("$storable_players");
  unlink("$storable_tables");
  unlink("$storable_dead");
  unlink("$storable_stack");
  unlink("$storable_whobeat");
  unlink("$storable_whobeat_csv");
  unlink("$storable_tourney_running");
  unlink("$status");
}

sub version {
  # Get current version from web page 
  my $url = 'https://lightningchip.xyz/version.html';
 
  my $response = HTTP::Tiny->new->get($url);
  if ($response->{success}) {
    if (length $response->{content}) {
	my $send_back = $response->{content};
	chomp($send_back);
	return $send_back;
    }
    print "\n";
  } else {
    print "Failed: $response->{status} $response->{reasons}";
    return $version;
  }
}
