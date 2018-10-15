#!/usr/bin/perl

###########################
#                         #
# Lightening Chip Tourney #
#     Martin Colello      #
#   April/May/June 2018   #
#                         #
# Add move table Aug 2018 #
#                         #
# Add player db Oct 2018  #
#                         #
###########################

use strict;
use Term::ReadKey;
use List::Util 'shuffle';
use Term::ANSIColor;
use POSIX;
$SIG{INT} = 'IGNORE';

# Get current date
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
if ( $min < 10 ) { $min = "0$min" }
if ( $sec < 10 ) { $sec = "0$sec" }
$year = $year + 1900;

my @abbr = qw(January February March April May June July August September October November December);
my $DATE = "$hour".':'."$min".":$sec"."_$abbr[$mon]"."_$mday"."_$year";

# Set output file to user's Desktop
my $fargo_storage_file = 'fargo.txt';
my $chip_rating_storage_file = 'chip_rating.txt';
my $player_db = 'chip_player.txt';
my $desktop     = 'chip_results_'."$abbr[$mon]"."_$mday"."_$year".'.txt';
my $desktop_csv = 'chip_results_'."$abbr[$mon]"."_$mday"."_$year".'.csv';
my $windows_ver = 'none';
my $png = 'Lightning.png';

if ( $^O =~ /MSWin32/ ) {
  chomp(my $profile = `set userprofile`);
  $profile     =~ s/userprofile=//i;
  $desktop     = $profile . "\\desktop\\$desktop";
  $desktop_csv = $profile . "\\desktop\\$desktop_csv";
  if ( exists $ENV{'LOCALAPPDATA'} ) {
    my $local_app_data = $ENV{'LOCALAPPDATA'};
    $fargo_storage_file = "$local_app_data\\$fargo_storage_file";
    $chip_rating_storage_file = "$local_app_data\\$chip_rating_storage_file";
    $player_db = "$local_app_data\\$player_db";
    $png = "$local_app_data\\$png";
  } else {
    $fargo_storage_file = $profile . "\\desktop\\$fargo_storage_file";
    $chip_rating_storage_file = $profile . "\\desktop\\$chip_rating_storage_file";
    $player_db = $profile . "\\desktop\\$player_db";
    $png = $profile . "\\desktop\\$png";
  }
  $windows_ver = `ver`;
}

# Display logo
if ( -e $png ) {
  if ( $^O =~ /MSWin32/     ) { system("start $png") }
  if ( $^O =~ /next|darwin/ ) { system("open $png") }
}

# Hold state of screen in case we need to exit program
my $screen_contents;

# Set outfile for final results
my $outfile     = "$desktop";
my $outfile_csv = "$desktop_csv";

# Open log file
open OUTFILE, ">$outfile" or die "Cannot open results file: $!";
print OUTFILE "$abbr[$mon]".' '."$mday".' '."$year"."\n";
print OUTFILE "Lightning Chip Tourney results:                      --by Martin Colello\n\n";

# Setup some global hashes and variables
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
my $most_recent_loser = 'none';  # Keep track of who lost recently for stack manipulation
my $most_recent_winner = 'none'; # Keep track of who lost recently for stack manipulation
my $game = 'none';               # Store game type (8/9/10 ball)
my $event;                       # Store Event name (Freezer's Chip etc)
my $shuffle_mode = 'off';        # Keep track of shuffle mode off/on
my $send = 'none';               # Keep track of send new player to table information
my $chips_8 = 461;
my $chips_7 = 521;
my $chips_6 = 581;
my $chips_5 = 641;
my $chips_4 = 1001;
if ( $windows_ver =~ /Version 10/  ) {
  $Colors = 'on';
} else {
  $Colors = 'off';
}

print color($color) unless ( $Colors eq 'off');

# Set the size of the console
if ( $^O =~ /MSWin32/ ) {
  system("mode con lines=60 cols=120");
}
if ( $^O =~ /darwin/ ) {
  system("osascript -e 'tell app \"Terminal\" to set background color of first window to {0, 0, 0, -16373}'");
  system("osascript -e 'tell app \"Terminal\" to set font size of first window to \"12\"'");
  system("osascript -e 'tell app \"Terminal\" to set bounds of front window to {300, 30, 1200, 900}'");
}

# If names.txt exits populate the tourney with sample data
if ( -e 'names.txt' ) {
  my $filename = 'names.txt';
  open my $handle, '<', $filename;
  my @names = <$handle>;
  close $handle;
  chomp(@names);
  foreach(@names) {
    my $line = $_;
    my @split = split /:/, $line;
    $players{$split[0]}{'chips'} = $split[1];
    $players{$split[0]}{'table'} = $split[2];
    $players{$split[0]}{'fargo_id'} = $split[3];
    $players{$split[0]}{'won'} = 0;
  }
  $tables{'6'}=1;
  $tables{'5'}=1;
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
yesorno('any');

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
      print OUTFILE "$screen_contents\n\n";

      # Print list of who beat who to log file
      @whobeat = sort(@whobeat);
      foreach(@whobeat) {
	my $line = $_;
        print OUTFILE "$_";
      }
      close OUTFILE;

      history();

      # Open log file
      if ( $^O =~ /MSWin32/     ) { system("start notepad.exe $desktop") }
      if ( $^O =~ /next|darwin/ ) { system("open $desktop") }
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
      $done = 1 if $choice eq 'G';
      $done = 1 if $choice eq 'R';
      $done = 1 if $choice eq 'T';
      $done = 1 if $choice eq 'C';
      $done = 1 if $choice eq 'P';
      if ( $tourney_running eq 1 ) {
        $done = 1 if $choice eq 'M';
        $done = 1 if $choice eq 'H';
        $done = 1 if $choice eq 'L';
        $done = 1 if $choice eq 'S';
        $done = 1 if $choice eq 'E';
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
  if ( $choice eq 'S'  ) { shuffle_stack()      }
  if ( $choice eq 'E'  ) { enter_shuffle_mode() }
  if ( $choice eq 'C'  ) { switch_colors()      }
  if ( $choice eq 'M'  ) { move_player()        }
  if ( $choice eq 'H'  ) { history()            }
  if ( $choice eq 'P'  ) { new_player_from_db() }

}# End of MAIN LOOP

sub draw_screen {
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
  if ( $min < 10 ) { $min = "0$min" }
  if ( $sec < 10 ) { $sec = "0$sec" }
  $year = $year + 1900;

  my @abbr = qw(January February March April May June July August September October November December);
  $DATE = "$hour".':'."$min".":$sec"."_$abbr[$mon]"."_$mday"."_$year";
  $screen_contents = "\n";

  # Count the number of players still alive
  my $number_of_players = 0;
  my @countplayers = keys(%players);
  $number_of_players = @countplayers;

  header();

  print color('bold white') unless ( $Colors eq 'off');;
  if ( $number_of_players > 0 ) {
    print "Player:                        Won:       Chips:     Table:\n\n";
  }
  $screen_contents .= "Player:                        Won:       Chips:     Table:\n\n";
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
    my $line  = "$table:$player:$chips:$won";
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
      my $chips  = $split[2];
      my $won    = $split[3];
      if ( $table eq 'none' ) { $table = 'In line' }
      my $printit = sprintf ( "%-30s %-10s %-10s %-8s\n", "$player", "$won", "$chips", "$table" );
      if ( $tourney_running eq 0 ) { 
        $printit = sprintf ( "%-30s %-10s %-10s %-8s\n", "$player", "$won", "$chips", " " );
      }
      if (( $stack_player eq $player ) and ( $table eq 'In line' )) {
        push @final_display, $printit;
      }
    }
  }
  my $blank_line = "\n";
  push @final_display, "$blank_line";

  # Add lines WITH table numbers to array
  foreach(@display_sort) {
    my $line = $_;
    my @split  = split /:/, $line;
    my $table  = $split[0];
    my $player = $split[1];
    my $chips  = $split[2];
    my $won    = $split[3];
    my $printit = sprintf ( "%-30s %-10s %-10s %-8s\n", "$player", "$won", "$chips", "$table" );
    if ( $table !~ /none/ ) {
      push @final_display, $printit;
    }
  }

  # Print to screen in correct TABLE order
  my $first_line = 'yes';
  my $color  = 'bold white';
  foreach(@final_display) {
    my $line   = $_;
    print color($color) unless ( $Colors eq 'off');;
    if ( $color eq 'bold white'  ) { $color = 'bold cyan' } else { $color = 'bold white' }
    if ($first_line eq 'yes') {
      $line =~ s/In line/Next up/;
      $first_line = 'no';
    }
    if ($shuffle_mode eq 'on') {
      $line =~ s/In line/ /;
      $line =~ s/Next up/ /;
    }
    print "$line";
    $screen_contents .= $line;
  }
  $color  = 'bold white';
  print color($color) unless ( $Colors eq 'off');;

  print "\n";
  @dead = sort(@dead);

  # Print to screen the list of dead players in RED font
  foreach(@dead) {
    my $line = $_;
    my @split = split /:/, $line;
    my $deadname = $split[0];
    my $deadwon  = $split[1];
    my $color  = 'bold red';
    print color($color) unless ( $Colors eq 'off');;
    my $printit = sprintf ( "%-29s %-10s\n", "$deadname", "$deadwon" );
    print "$printit";
    $screen_contents .= $printit;
  }
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
    #print "(n)ew player (d)elete player (a)dd table (r)emove table (g)ive chip (t)ake chip (q)uit program (b)egin tourney!\n";
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
    print ")olors\n(";
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
    print ")egin tourney!\n";
  }
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
    print ")elete player  (";
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
    print ")uit\n(";
    print color('bold yellow') unless ( $Colors eq 'off');
    print "G";
    print color('bold white') unless ( $Colors eq 'off');
    print ")ive chip (";
    print color('bold yellow') unless ( $Colors eq 'off');
    print "T";
    print color('bold white') unless ( $Colors eq 'off');
    print ")ake chip  (";
    print color('bold yellow') unless ( $Colors eq 'off');
    print "P";
    print color('bold white') unless ( $Colors eq 'off');
    print ")layer from db (";
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

    my @count_players = keys(%players);
    my $count_players = @count_players;
    if ( ( $tourney_running eq 1 ) and ( $Colors eq 'on'  ) and ( $shuffle_mode eq 'on' ) )  {
      print colored("\n\n      SHUFFLE MODE       SHUFFLE MODE       SHUFFLE MODE       SHUFFLE MODE       SHUFFLE MODE      ", 'bright_yellow on_red'), "\n\n\n";
    }
    if ( ( $tourney_running eq 1 ) and ( $Colors eq 'off' ) and ( $shuffle_mode eq 'on' ) )  {
      print "\n\nSHUFFLE MODE       SHUFFLE MODE       SHUFFLE MODE       SHUFFLE MODE       SHUFFLE MODE\n";
    }
    if ( ( $send ne 'none' ) and ( $shuffle_mode ne 'on' ) ) {
      print color('bold green') unless ( $Colors eq 'off');
      print "$send";
      print color('bold white') unless ( $Colors eq 'off');
    }
  }
}

sub loser {
  # Actions to take when selecting a loser

  header();
  
  # Get list of players from hash, and sort them
  my @players = keys(%players);
  @players = sort(@players);
  
  print "\n\n\n\nPlease choose number of player who lost:\n\n";
  my @active_players;
  foreach(@players) {
    my $player = $_;
    if ( $players{$player}{'table'} ne 'none' ) {
      push @active_players, $player;
    }
  }

  my $numselection = print_menu_array(@active_players);  
  if ( $numselection == 1000 ) {
    return;
  }
  my $player = $active_players[$numselection];
  chomp($player);

  if ( $players{$player}{'table'} eq 'none' ) {
    print "Error, this player was not at a table.\n";
    sleep 5;
    return;
  }

    # Take away a chip.  :)
    $most_recent_loser = $player;
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
	  $opponent = $possible_opponent;
          $most_recent_winner = $opponent;
	  push @whobeat, $printit;
	  push @whobeat_csv, "$possible_opponent"."SPLIT"."$player"."SPLIT"."$players{$possible_opponent}{'table'}"."SPLIT"."$players{$possible_opponent}{'fargo_id'}"."SPLIT"."$players{$player}{'fargo_id'}"."SPLIT"."$DATE";
        }	
      }
    }

    # Delete players from tourney if chips are zero
    delete_players();

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
    if (( $extra_players eq 'no' ) and ( $raw_tables_count > 3 )) {
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
      yesorno('any');
      delete $tables{$remove_table};
    }

    if (( $extra_players eq 'yes' ) and ( $shuffle_mode eq 'off' )) {

      foreach(@stack) {
        my $standup = $_;

        if ( $player eq $standup ) { next }

        if ( exists( $players{$standup} ) and ( $players{$standup}{'table'} eq 'none' ) ) { 
          $players{$standup}{'table'} = $table;
          header();
	  $send = "\n\nSend $standup to table $table\n";
          last;
        }
      }
    @stack=((grep $_ ne $player, @stack), $player);
    } 
    if ( $number_of_players < 5 ) {
      $shuffle_mode = 'on';
    }
    if ( $shuffle_mode eq 'on' ) {
      $players{$opponent}{'table'} = 'none';
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
  print "\n\n\n\n\n\nStart tourney now?\n";
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
  }
}

sub new_table {
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
  print "Add Table Number $name, correct?\n";
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
  header();

  my %fargo_id;
  my $potential_fargo_id = 0;
  my @fargo_storage;
  if ( -e $fargo_storage_file ) {
    open FARGO, "<$fargo_storage_file";
    @fargo_storage = <FARGO>;
    close FARGO;
  }

  my @player_db;
  if ( -e $player_db ) {
    open PLAYER_DB, "<$player_db";
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
  print color('bold white') unless ( $Colors eq 'off');

  print "Fargo Rating:\n";
  print color('bold cyan') unless ( $Colors eq 'off');
  chomp(my $fargo = <STDIN>);
  print color('bold white') unless ( $Colors eq 'off');
  if ( $fargo !~ /^\d+\z/ ) {
    $fargo = 0;;
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

  if ( $potential_fargo_id == 0 ) {
    print "Fargo ID Number:\n";
  } else {
    print "Fargo ID Number [$potential_fargo_id]:\n";
  }
  print color('bold cyan') unless ( $Colors eq 'off');
  chomp(my $fargo_id = <STDIN>);
  if (( $potential_fargo_id > 1 ) and ( $fargo_id eq "" )) {
    $fargo_id = $potential_fargo_id;
  }

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

  print "$name with $chips chips and Fargo ID $fargo_id, correct?\n";
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
    open OUT, ">$fargo_storage_file";
    my @fargo_id_keys = keys(%fargo_id);
    @fargo_id_keys = sort(@fargo_id_keys);
    foreach(@fargo_id_keys){
      my $key = $_;
      print OUT "$key:$fargo_id{$key}\n";
    }
    
    # Write out new player databases file
    $fargo_id{$name_lower} = $fargo_id;
    open OUT, ">$player_db";
    foreach(@player_db){
      my $line = $_;
      print OUT "$line\n";
    }
  } 
}

sub new_player_from_db {
  header();

  # If db file does not exist, exit subroutine.
  if ( ! -e $player_db ) { 
    print "No db yet.\n";
    sleep 1;
    return;
  }

  open DB, "<$player_db" or return;
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
  my $fargo_id = $split[1];

  print "Fargo Rating:\n";
  print color('bold cyan') unless ( $Colors eq 'off');
  chomp(my $fargo = <STDIN>);
  print color('bold white') unless ( $Colors eq 'off');
  if ( $fargo !~ /^\d+\z/ ) {
    $fargo = 0;;
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
  open DB, ">$player_db" or return;
  foreach(@db){
    print DB "$_\n";
  }
}
    

sub delete_player {


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
  print "Delete $player, correct?\n";
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

  print "Grant chip to $player, correct?\n";
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

  print "Take chip from $player, correct?\n";
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

  print "Delete table $table, correct?\n";
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
    #if ( $players{$most_recent_winner}{'table'} eq $table ) {
    #  $players{$most_recent_winner}{'table'} = 'none';
    #  @stack=((grep $_ ne $most_recent_winner, @stack), $most_recent_winner);
    #  my $tempplayer = pop @stack;
    #  unshift @stack, $tempplayer;
    #}
    return;
  } else {
    return
  } 
}

sub quit_program {
  header();
  print "\nQuitting will NOT save tourney data!!!\n";
  print "Are you sure?\n";
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
    if ( $^O =~ /MSWin32/ ) {
      system("start notepad.exe $desktop");
    }
    if ( $^O =~ /next|darwin/ ) {
      system("open $desktop");
    }
    exit;
  } else {
    return
  } 
}

sub yesorno {
  my $any = shift;
  if ( $any ne 'any' ) {print "(y/n)\n"}
  my $done = 0;
  my $choice;
  ReadMode 4;
  undef($key);
  while ( !$done ) {
    if ( defined( $key = ReadKey(-1) ) ) {
      $choice = uc ( $key);
      $done = 1 if $choice eq 'Y';
      $done = 1 if $choice eq 'N';
      $done = 1 if $any eq 'any';
    }
  }
  ReadMode 0;
  if ( $choice eq 'Y' ) { return 'y' }
  if ( $choice eq 'N' ) { return 'n' }
}

sub clear_screen {
  if ( $^O =~ /MSWin/             ) { system("cls"    ) }
  if ( $^O =~ /next|darwin|linux/ ) { system("clear"  ) }
}

sub shuffle_stack {
  header();
  print "\n\n\n\n\nThis will reshuffle ALL players including at current tables!!!\n";
  print "Are you sure?\n";
  my $yesorno = yesorno();
  chomp($yesorno);
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

    print "Shuffled.\n";
    sleep 1;
  }
}

sub delete_players {
  my @players = keys(%players);
  @players = sort(@players);
  foreach(@players){
    my $player = $_;
    if ( $players{$player}{'chips'} eq 0 ) {
      # Add player to dead player array
      push @dead, "$player: $players{$player}{'won'}";

      # Delete the player
      delete $players{$player}{'chips'};
      delete $players{$player}{'table'};
      delete $players{$player}{'won'};
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
      @stack = @new_stack;     delete $players{$player};
      }
  }
}

sub assign {
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
  if ( $sec < 10 ) { $sec = "0$min" }

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
      print colored("\nLIGHTNING CHIP TOURNEY                 Players: $number_of_players      $TIME              --by Martin Colello    ", 'bright_yellow on_blue'), "\n\n\n";
    } elsif ( $Colors eq 'off' ) {
      print "\nLIGHTNING CHIP TOURNEY                 Players: $number_of_players      $TIME              --by Martin Colello\n\n\n";
    }
  } else {
    if ( $Colors eq 'on' ) { 
      print colored("\nLIGHTNING CHIP TOURNEY     SHUFFLE     Players: $number_of_players      $TIME              --by Martin Colello    ", 'bright_yellow on_red'), "\n\n\n";
    } elsif ( $Colors eq 'off' ) {
      print "\nLIGHTNING CHIP TOURNEY      SHUFFLE    Players: $number_of_players      $TIME              --by Martin Colello\n\n\n";
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
      $one   =~ s/:.*//g;
      $two   =~ s/:.*//g;
      $three =~ s/:.*//g;
      my $printit = sprintf ( "%-30s %-30s %-30s", "$one", "$two", "$three" );
      push @display,"$printit";
    } else {
      last;
    }
  }

  foreach(@display) {
    print "$_\n";
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
  print "Please enter Event Name:\n";
  print "\nExample: Freezer's Lightning Nine Ball Chip Tourney\n\n";
  print color('bold cyan') unless ( $Colors eq 'off');
  chomp($event = <STDIN>);
  print color('bold white') unless ( $Colors eq 'off');
  print "\n\nPlease enter game type:\n";
  print "\nExample: Nine Ball\n\n";
  print color('bold cyan') unless ( $Colors eq 'off');
  chomp($game = <STDIN>);
  print color('bold white') unless ( $Colors eq 'off');
  chomp($event);
  chomp($game);

  my @chip_rating_storage;
  if ( -e $chip_rating_storage_file ) {
    open CHIP, "<$chip_rating_storage_file";
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
  open CHIP, ">$chip_rating_storage_file" or return;
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
  print "Are you sure?\n";
  my $yesorno = yesorno();
  chomp($yesorno);
  if ( $yesorno eq 'y' ) {
    if ( $shuffle_mode eq 'on' ) { 
      $shuffle_mode = 'off';
    } elsif ( $shuffle_mode eq 'off' ) {
      $shuffle_mode = 'on';
    }
  }
}

sub history {
  header();
  print "Opening history file...\n";
  open OUTCSV, ">$outfile_csv";
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
    $winner =~ s/\(\d+\)//g;
    $loser  =~ s/\(\d+\)//g;
    print OUTCSV "$winner_id,$winner,1,$loser_id,$loser,0,$date_lost,$game,$table,$event\n";
  }
  close OUTCSV;

  # Open log file
  if ( $^O =~ /MSWin32/     ) { system("start $outfile_csv") }
  if ( $^O =~ /next|darwin/ ) { system("open $outfile_csv") }
  print "Please wait...\n";
  sleep 2;
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
