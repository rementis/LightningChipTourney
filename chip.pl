#!/usr/bin/perl

###########################
#                         #
# Lightening Chip Tourney #
#     Martin Colello      #
#   April/May/June 2018   #
#                         #
###########################

use strict;
use Term::ReadKey;
use List::Util 'shuffle';
use Term::ANSIColor;
print color('bold white');

# Get current date
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
$year = $year + 1900;

my @abbr = qw(January February March April May June July August September October November December);

# Set output file to user's Desktop
my $desktop     = 'chip_results_'."$abbr[$mon]"."_$mday"."_$year".'.txt';
my $desktop_csv = 'chip_results_'."$abbr[$mon]"."_$mday"."_$year".'.csv';
my $DATE = "$abbr[$mon]"."_$mday"."_$year";

if ( $^O =~ /MSWin32/ ) {
  chomp(my $profile = `set userprofile`);
  $profile     =~ s/userprofile=//i;
  $desktop     = $profile . "\\desktop\\$desktop";
  $desktop_csv = $profile . "\\desktop\\$desktop_csv";
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
my $color  = 'bold white'; # Default text color to start with
my $key;                   # Generic holder for hash keys
my %players;               # Hash which contains tourney players
my %tables;                # Hash which contains billiard tables in use
my $tourney_running = 0;   # Determine if tourney is currently started
my @stack;                 # Array used to keep the players in order
my @dead;                  # Hold list of players with zero chips
my @whobeat;               # Record who beat who
my @whobeat_csv;           # Record who beat who for spreadsheet
print color($color);

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
    $players{$split[0]}{'won'} = 0;
  }
  $tables{'6'}=1;
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
    if (( $number_of_players < 2 ) or ( $tables_in_use eq 0 )){
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

      open OUTCSV, ">$outfile_csv";
      print OUTCSV "Player #1,,,Player #2,\n";
      print OUTCSV "Fargo ID,Player Name,Score,Fargo ID,Player Name,Score,Date,Game,Table,Event\n";
      foreach(@whobeat_csv) {
	my $line = $_;
	my @split = split /:/, $line;
	my $winner = $split[0];
	my $loser  = $split[1];
	my $table  = $split[2];
	$winner =~ s/\(\d+\)//g;
	$loser  =~ s/\(\d+\)//g;
	print OUTCSV ",$winner,1,,$loser,0,$DATE,,$table\n";
      }
      close OUTCSV;

      # Open log file
      if ( $^O =~ /MSWin32/     ) { system("start notepad.exe $desktop") }
      if ( $^O =~ /MSWin32/     ) { system("start $outfile_csv") }
      if ( $^O =~ /next|darwin/ ) { system("open $desktop") }
      if ( $^O =~ /next|darwin/ ) { system("open $outfile_csv") }
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
      if ( $tourney_running eq 1 ) {
        $done = 1 if $choice eq 'L';
        $done = 1 if $choice eq 'S';
        $done = 1 if $choice eq 'RE';
      }
      if ( $tourney_running eq 0 ) {
        $done = 1 if $choice eq 'B';
      }
    }
  }
  ReadMode 0;

  # Call subroutines based on menu selection
  if ( $choice eq 'Q'  ) { quit_program()  }
  if ( $choice eq 'N'  ) { new_player()    }
  if ( $choice eq 'D'  ) { delete_player() }
  if ( $choice eq 'A'  ) { new_table()     }
  if ( $choice eq 'R'  ) { delete_table()  }
  if ( $choice eq 'B'  ) { start_tourney() }
  if ( $choice eq 'G'  ) { give_chip()     }
  if ( $choice eq 'T'  ) { take_chip()     }
  if ( $choice eq 'L'  ) { loser()         }
  if ( $choice eq 'S'  ) { shuffle_stack() }
}# End of MAIN LOOP

sub draw_screen {
  $screen_contents = "\n";

  # Count the number of players still alive
  my $number_of_players = 0;
  my @countplayers = keys(%players);
  $number_of_players = @countplayers;

  header();

#  if ( $tourney_running eq 0 ) { print colored("\nLIGHTNING CHIP TOURNEY                                                  --by Martin Colello", 'bright_yellow on_red'), "\n\n\n" }

#  if ( $tourney_running eq 1 ) { print colored("\nLIGHTNING CHIP TOURNEY            Players left: $number_of_players                         --by Martin Colello", 'bright_yellow on_red'), "\n\n\n" }

  print color('bold white');
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
      my $printit = sprintf ( "%-30s %-10s %-10s %-8s\n", "$player", "$won", "$chips", "$table" );
      if (( $stack_player eq $player ) and ( $table eq 'none' )) {
        push @final_display, $printit;
      }
    }
  }

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
  my $color  = 'bold white';
  foreach(@final_display) {
    my $line   = $_;
    print color($color);
    if ( $color eq 'bold white'  ) { $color = 'bold cyan' } else { $color = 'bold white' }
    print "$line";
    $screen_contents .= $line;
  }
  $color  = 'bold white';
  print color($color);

  print "\n";
  @dead = sort(@dead);

  # Print to screen the list of dead players in RED font
  foreach(@dead) {
    my $line = $_;
    my @split = split /:/, $line;
    my $deadname = $split[0];
    my $deadwon  = $split[1];
    my $color  = 'bold red';
    print color($color);
    my $printit = sprintf ( "%-29s %-10s\n", "$deadname", "$deadwon" );
    print "$printit";
    $screen_contents .= $printit;
  }
    my $color  = 'bold white';
    print color($color);

    if ( $number_of_players < 1 ) {
      print "Tournament is empty.\n\nPlease add at least one table and some players.\n\n";
    }

  # Print menu
  print "\n\n";
  if ( $tourney_running eq 0 ) {
    #print "(n)ew player (d)elete player (a)dd table (r)emove table (g)ive chip (t)ake chip (q)uit program (b)egin tourney!\n";
    print "(";
    print color('bold yellow');
    print "n";
    print color('bold white');
    print ")ew player (";
    print color('bold yellow');
    print "d";
    print color('bold white');
    print ")elete player (";
    print color('bold yellow');
    print "a";
    print color('bold white');
    print ")dd table (";
    print color('bold yellow');
    print "r";
    print color('bold white');
    print ")emove table (";
    print color('bold yellow');
    print "g";
    print color('bold white');
    print ")ive chip (";
    print color('bold yellow');
    print "t";
    print color('bold white');
    print ")ake chip (";
    print color('bold yellow');
    print "q";
    print color('bold white');
    print ")uit program (";
    print color('bold yellow');
    print "b";
    print color('bold white');
    print ")egin tourney!\n";
  }
  # Print menu
  if ( $tourney_running eq 1 ) {
    #print "(l)oser (n)ew player (d)elete player (r)emove table (a)dd table (g)ive chip (t)ake chip (q)uit program\n";
    print "(";
    print color('bold yellow');
    print "l";
    print color('bold white');
    print ")oser (";
    print color('bold yellow');
    print "n";
    print color('bold white');
    print ")ew player (";
    print color('bold yellow');
    print "d";
    print color('bold white');
    print ")elete player (";
    print color('bold yellow');
    print "a";
    print color('bold white');
    print ")dd table (";
    print color('bold yellow');
    print "r";
    print color('bold white');
    print ")emove table (";
    print color('bold yellow');
    print "g";
    print color('bold white');
    print ")ive chip (";
    print color('bold yellow');
    print "t";
    print color('bold white');
    print ")ake chip (";
    print color('bold yellow');
    print "s";
    print color('bold white');
    print ")huffle (";
    print color('bold yellow');
    print "q";
    print color('bold white');
    print ")uit\n";
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
  my $num = 0;
  my $list_color = 'bold white';
  foreach(@active_players) {
    print color("$list_color");
    my $player = $_;
    $num++;
    if ( $players{$player}{'table'} ne 'none' ) {
    if ( $list_color eq 'bold white'  ) { $list_color = 'bold cyan' } else { $list_color = 'bold white' }
      print color("$list_color");
      print "$num: $player\n";
    }
  }
  print color('bold white');
  print "\n";
  my $numselection = <STDIN>;
  chomp($numselection);
  if ( $numselection !~ /\d/) {
    print "Needed to enter a number, exiting...\n";
    sleep 1;
    return;
  }

  if ( ($numselection > $num) or ($numselection == 0) ) {
    print "Invalid selection, exiting...\n";
    sleep 1;
    return;
  }

  $numselection--;
  
  my $player = $active_players[$numselection];
  chomp($player);

  if ( $players{$player}{'table'} eq 'none' ) {
    print "Error, this player was not at a table.\n";
    sleep 5;
    return;
  }

  print "\n$player lost, correct?\n";
  my $yesorno = yesorno();
  chomp($yesorno);
  if ( $yesorno eq 'y' ) {

    # Take away a chip.  :)
    $players{$player}{'chips'}--;

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
	  push @whobeat, $printit;
	  push @whobeat_csv, "$possible_opponent:$player:$players{$possible_opponent}{'table'}";
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
    if ( $extra_players eq 'no' ) {
      my $remove_table = $players{$opponent}{'table'};
      $players{$opponent}{'table'} = 'none';
      header();
      print "\n\n\n\n\n\n\n\n";
      print color('bold red');
      print "**************\n";
      print "*** NOTICE ***\n";
      print "**************\n\n";
      print color('bold white');
      print "\n\n\nRemoving table $remove_table from tourney.  $opponent gets back in line.\n\nAny key to continue.\n";
      yesorno('any');
      delete $tables{$remove_table};
    }

    if ( $extra_players eq 'yes' ) {

      foreach(@stack) {
        my $standup = $_;

        if ( $player eq $standup ) { next }

        if ( exists( $players{$standup} ) and ( $players{$standup}{'table'} eq 'none' ) ) { 
          $players{$standup}{'table'} = $table;
          header();
          print "\n\n\n\n\n\n\nSend $standup to table $table\n\n<any key>\n";
          yesorno('any');
          last;
        }
      }
    @stack=((grep $_ ne $player, @stack), $player);
    } 
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
  print color($color);
  print "Current tables:\n";

  foreach(@tables) { 
    if ( $color eq 'bold white'  ) { $color = 'bold cyan' } else { $color = 'bold white' }
    print color($color);
    print "$_\n";
  }

  $color = 'bold white';
  print color($color);
  print "\n\nTable Number:\n";
  print color('bold cyan');
  chomp(my $name = <STDIN>);
  print color('bold white');
  print "Add Table Number $name, correct?\n";
  my $yesorno = yesorno();
  chomp($yesorno);
  if ( $yesorno eq 'y' ) {
    $tables{$name} = 1;
    # Sort through stack and grab player that has table set to none
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
  print "Player Name:\n";
  print color('bold cyan');
  chomp(my $name = <STDIN>);
  print color('bold white');

  print "Fargo Rating:\n";
  print color('bold cyan');
  chomp(my $fargo = <STDIN>);
  print color('bold white');
  if ( $fargo !~ /^\d+\z/ ) {
    print "Fargo rating must be a number.\n";
    sleep 3;
    return;
  }

  $name = "$name ($fargo)";
  if ( exists($players{$name}) ) {
    print "Player already exists.\n";
    sleep 3;
    return;
  }

  print "Number of chips:\n";
  print color('bold cyan');
  chomp(my $chips = <STDIN>);
  print color('bold white');
  if ( $chips !~ /^\d+\z/ ) {
    print "Chips must be a number.\n";
    sleep 3;
    return;
  }
  print "$name with $chips chips, correct?\n";
  my $yesorno = yesorno();
  chomp($yesorno);
  if ( $yesorno eq 'y' ) {
    $players{$name}{'chips'} = $chips;
    $players{$name}{'table'} = 'none';
    $players{$name}{'fargo'} = $fargo;
    $players{$name}{'won'} = 0;

    # If tourney is already started, put new player at the top of the stack
    if ( $tourney_running eq 1 ) {
      unshift @stack, $name;
    }
  } else {
    return
  } 
}

sub delete_player {

  my @players = keys(%players);
  @players = sort(@players);

  header();
  $color = 'bold white';
  print color($color);
  print "\nPlease choose number of player to delete:\n\n";
  my $num = 0;
  foreach(@players) {
    my $player = $_;
    $num++;
    if ( $color eq 'bold white'  ) { $color = 'bold cyan' } else { $color = 'bold white' }
    print color($color);
    print "$num: $player\n";
  }
  print "\n";
  $color = 'bold white';
  print color($color);
  my $numselection = <STDIN>;
  chomp($numselection);
  if ( $numselection !~ /\d/) {
    print "Needed to enter a number, exiting...\n";
    sleep 1;
    return;
  }

  if ( ($numselection > $num) or ($numselection == 0) ) {
    print "Invalid selection, exiting...\n";
    sleep 1;
    return;
  }

  $numselection--;
  
  my $player = $players[$numselection];
  chomp($player);

  print "THIS WILL REMOVE PLAYER FROM TOURNEY\n";
  print "Delete $player, correct?\n";
  my $yesorno = yesorno();
  chomp($yesorno);
  if ( $yesorno eq 'y' ) {
    if ( $players{$player}{'table'} ne 'none' ) { 
      print "Cannot delete player who is at a table.\n";
      sleep 5;
    }  
    delete $players{$player};
    return;
  } else {
    return
  } 
}

sub give_chip {

  my @players = keys(%players);
  @players = sort(@players);

  $color = 'bold white';
  print color($color);
  header();
  print "\nPlease choose number of player to give chip:\n\n";
  my $num = 0;
  foreach(@players) {
    my $player = $_;
    $num++;
    if ( $color eq 'bold white'  ) { $color = 'bold cyan' } else { $color = 'bold white' }
    print color($color);
    print "$num: $player\n";
  }
  print "\n";
  my $numselection = <STDIN>;
  $color = 'bold white';
  print color($color);
  chomp($numselection);
  if ( $numselection !~ /\d/) {
    print "Needed to enter a number, exiting...\n";
    sleep 1;
    return;
  }

  if ( ($numselection > $num) or ($numselection == 0) ) {
    print "Invalid selection, exiting...\n";
    sleep 1;
    return;
  }

  $numselection--;
  
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
  print color($color);
  print "\nPlease choose number of player to take chip:\n\n";
  my $num = 0;
  foreach(@players) {
    my $player = $_;
    $num++;
    if ( $color eq 'bold white'  ) { $color = 'bold cyan' } else { $color = 'bold white' }
    print color($color);
    print "$num: $player\n";
  }
  print "\n";
  my $numselection = <STDIN>;
  $color = 'bold white';
  print color($color);
  chomp($numselection);
  if ( $numselection !~ /\d/) {
    print "Needed to enter a number, exiting...\n";
    sleep 1;
    return;
  }

  if ( ($numselection > $num) or ($numselection == 0) ) {
    print "Invalid selection, exiting...\n";
    sleep 1;
    return;
  }

  $numselection--;
  
  my $player = $players[$numselection];
  chomp($player);

  print "Take chip from $player, correct?\n";
  my $yesorno = yesorno();
  chomp($yesorno);
  if ( $yesorno eq 'y' ) {
    if ( $players{$player}{'table'} ne 'none' ) {
      print "Cannot take chip from player who is at table.\n";
      sleep 3;
      return;
    }
    $players{$player}{'chips'} = $players{$player}{'chips'} - 1;
    delete_players();
    return;
  } else {
    return
  } 
}

sub delete_table {

  my @tables = keys(%tables);
  @tables = sort { $a <=> $b } (@tables);

  header();
  print "\nPlease choose number of table to delete:\n\n";
  my $num = 0;
  foreach(@tables) {
    my $table = $_;
    $num++;
    if ( $color eq 'bold white'  ) { $color = 'bold cyan' } else { $color = 'bold white' }
    print color($color);
    print "$num: $table\n";
  }
  print "\n";
  my $numselection = <STDIN>;
  chomp($numselection);
  if ( $numselection !~ /\d/) {
    print "Needed to enter a number, exiting...\n";
    sleep 1;
    return;
  }

  if ( ($numselection > $num) or ($numselection == 0) ) {
    print "Invalid selection, exiting...\n";
    sleep 1;
    return;
  }

  $numselection--;
  
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
    print "Shuffling players...\n";
    @stack = keys(%players);
    @stack = shuffle(@stack);

    # Reset all players to table 'none'
    foreach(@stack) {
      my $stackplayer = $_;
      #if ( exists($players{$stackplayer}) ) {
      $players{$stackplayer}{'table'} = 'none';
      #}
    }

    # Assign two players per table from the stack
    assign();

    sleep 1;
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
      delete $players{$player};
    }
  }
}

sub assign {
  my @tables = keys(%tables);
  foreach(@tables) {
    my $table = $_;
    my $player1 = shift(@stack);
    push @stack, $player1;
    my $player2 = shift(@stack);
    push @stack, $player2;
    $players{$player1}{'table'} = "$table";
    $players{$player2}{'table'} = "$table";
  }
}

sub header {
  clear_screen();
  # Count the number of players still alive
  my $number_of_players = 0;
  my @countplayers = keys(%players);
  $number_of_players = @countplayers;
  if ( $tourney_running eq 0 ) { print colored("\nLIGHTNING CHIP TOURNEY                                                  --by Martin Colello", 'bright_yellow on_red'), "\n\n\n" }

  if ( $tourney_running eq 1 ) { print colored("\nLIGHTNING CHIP TOURNEY            Players left: $number_of_players                         --by Martin Colello", 'bright_yellow on_red'), "\n\n\n" }
  print color('bold white');
}

