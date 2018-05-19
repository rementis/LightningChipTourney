#!/usr/bin/perl

###########################
#                         #
# Lightening Chip Tourney #
#     Martin Colello      #
#     April/May 2018      #
#                         #
###########################
use strict;
use Term::ReadKey;
use List::Util 'shuffle';
use Term::ANSIColor;

# Set output file to user's Desktop
my $desktop = 'chip_results.txt';

if ( $^O =~ /MSWin32/ ) {
  chomp(my $profile = `set userprofile`);
  $profile =~ s/userprofile=//i;
  $desktop = $profile . "\\desktop\\chip_results.txt";
}

# Hold state of screen in case we need to exit program
my $screen_contents;

# Set outfile for final results
my $outfile = "$desktop";

# Get current date and open log file
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
$year = $year + 1900;
open OUTFILE, ">$outfile" or die "Cannot open results file: $!";
print OUTFILE "$mon".'/'."$mday".'/'."$year"."\n";
print OUTFILE "Lightning Chip Tourney results:                      --by Martin Colello\n\n";

# Setup some global hashes and variables
my $color  = 'bold white';
my $key;
my %players;               # Hash which contains tourney players
my %tables;                # Hash which contains billiard tables in use
my $tourney_running = 0;   # Determine if tourney is currently started
my @stack;                 # Array used to keep the players in order
my @dead;                  # Hold list of players with zero chips
my @whobeat;               # Record who beat who
print color($color);

# Set the size of the console
if ( $^O =~ /MSWin32/ ) {
  system("mode con lines=60 cols=120");
}
if ( $^O =~ /darwin/ ) {
  system("osascript -e 'tell app \"Terminal\" to set background color of first window to {0, 0, 0, -16373}'");
  system("osascript -e 'tell app \"Terminal\" to set font size of first window to \"12\"'");
  system("osascript -e 'tell app \"Terminal\" to set bounds of front window to {300, 30, 1200, 900}'");
  #system("osascript -e 'tell app \"Terminal\" to set number of columns to 120'");
  #system("osascript -e 'tell app \"Terminal\" to set number of rows to 60'");
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
  $tables{'5'}=1;
  $tables{'9'}=1;
  $tables{'3'}=1;
  $tables{'11'}=1;
}

print "\n\n\n\n\n";
print " _     _       _     _         _                ____ _     _       \n";
print "| |   (_) __ _| |__ | |_ _ __ (_)_ __   __ _   / ___| |__ (_)_ __  \n";
print "| |   | |/ _` | '_ \\| __| '_ \\| | '_ \\ / _` | | |   | '_ \\| | '_ \ \n";
print "| |___| | (_| | | | | |_| | | | | | | | (_| | | |___| | | | | |_) |\n";
print "|_____|_|\\__, |_| |_|\\__|_| |_|_|_| |_|\\__, |  \\____|_| |_|_| .__/ \n";
print "         |___/                         |___/                |_|    \n\n\n\n\n\n";
print "                                           --by Martin Colello\n";

yesorno('any');

# MAIN LOOP of program
while(1) {

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
        print OUTFILE "$_";
      }
      close OUTFILE;

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
      if ( $tourney_running eq 1 ) {
        $done = 1 if $choice eq 'L';
        $done = 1 if $choice eq 'S';
      }
      if ( $tourney_running eq 0 ) {
        $done = 1 if $choice eq 'B';
      }
    }
  }
  ReadMode 0;

  # Call subroutines based on menu selection
  if ( $choice eq 'Q' ) { quit_program()  }
  if ( $choice eq 'N' ) { new_player()    }
  if ( $choice eq 'D' ) { delete_player() }
  if ( $choice eq 'A' ) { new_table()     }
  if ( $choice eq 'R' ) { delete_table()  }
  if ( $choice eq 'B' ) { start_tourney() }
  if ( $choice eq 'G' ) { give_chip()     }
  if ( $choice eq 'T' ) { take_chip()     }
  if ( $choice eq 'L' ) { loser()         }
  if ( $choice eq 'S' ) { shuffle_stack() }
}# End of MAIN LOOP

sub draw_screen {
  $screen_contents = "\n";

  # Count the number of players still alive
  my $number_of_players = 0;
  my @countplayers = keys(%players);
  $number_of_players = @countplayers;

  clear_screen();
  print color('bold yellow');
  if ( $tourney_running eq 0 ) { print "\nLIGHTNING CHIP TOURNEY                                                     --by Martin Colello\n\n" }
  if ( $tourney_running eq 1 ) { print "\nLIGHTNING CHIP TOURNEY            Players left: $number_of_players                         --by Martin Colello\n\n" }
  print color('bold white');
  if ( $number_of_players > 0 ) {
    print "Player:                        Won:       Chips:     Table:\n\n";
  }
  $screen_contents .= "Player:                        Won:       Chips:     Table:\n\n";
  my @players = keys(%players);

  # Check if any player has zero chips and if so delete them.
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
  @players = keys(%players);
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

  # Print to screen in correct order
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
    print ")uit program \n";
  }
}

sub loser {
  # Actions to take when selecting a loser

  clear_screen();
  
  # Get list of players from hash, and sort them
  my @players = keys(%players);
  @players = sort(@players);
  
  print "\n\n\n\nPlease choose number of player who lost:\n";
  my @active_players;
  foreach(@players) {
    my $player = $_;
    if ( $players{$player}{'table'} ne 'none' ) {
      push @active_players, $player;
    }
  }
  my $num = 0;
  foreach(@active_players) {
    my $player = $_;
    $num++;
    if ( $players{$player}{'table'} ne 'none' ) {
      print "$num: $player\n";
    }
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
        }	
      }
    }

    # Delete player from tourney if chips are zero
    if ( $players{$player}{'chips'} < 1 ) { 
      push @dead, "$player: $players{$player}{'won'}";
      delete $players{$player}; 
    }

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
      clear_screen();
      print "\n\n\n\n\n\n\n\n";
      print "**************\n";
      print "*** NOTICE ***\n";
      print "**************\n\n";
      print "\n\n\nRemoving table $remove_table from tourney.  $opponent gets back in line.\n\nAny key to continue.\n";
      yesorno('any');
      delete $tables{$remove_table};
    }

    if ( $extra_players eq 'yes' ) {
      while (1) {
        my $standup = shift(@stack);
	my $standup2 = 'nothing';

	# Skip to next in stack if player is same as standup :)
	if ( $player eq $standup ) {
          $standup2 = shift(@stack);
	}

	if ( $standup2 eq 'nothing' ) {
          push @stack, $standup;
        } else {
          push @stack, $standup2;
          push @stack, $standup;
	  $standup = $standup2;
	}

        if ( exists( $players{$standup} ) and ( $players{$standup}{'table'} eq 'none' ) ) { 
          $players{$standup}{'table'} = $table;
	  clear_screen();
	  print "\n\n\n\n\n\n\nSend $standup to table $table\n\n<any key>\n";
	  yesorno('any');
          last;
        }   
      }
    } 
    return;
  } 
}

sub start_tourney {
  clear_screen();

  # Count the number of tables
  my @counttables = keys(%tables);
  my $counttables = @counttables;

  # If no tables added we can't start the tourney
  if ( $counttables eq 0 ) {
    print "No tables added yet.\n";
    sleep 3;
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
    my @tables = keys(%tables);

    # Assign two players per table from the stack
    foreach(@tables) {
      my $table = $_;
      my $player1 = shift(@stack);
      push @stack, $player1;
      my $player2 = shift(@stack);
      push @stack, $player2;
      $players{$player1}{'table'} = "$table";
      $players{$player2}{'table'} = "$table";
    }
    @players = keys(%players);

    # Set number of games won to zero for each player
    foreach(@players) {
      my $player = $_;
      $players{$player}{'won'} = 0;
    }
  }
}

sub new_table {
  clear_screen();
  my @tables = keys(%tables);
  chomp(@tables);
  @tables = sort { $a <=> $b } @tables;
  print "Current tables:\n";
  foreach(@tables) {
    print "$_\n";
  }
  print "\n\nTable Number:\n";
  print color('bold cyan');
  chomp(my $name = <STDIN>);
  print color('bold white');
  print "Add Table Number $name, correct?\n";
  my $yesorno = yesorno();
  chomp($yesorno);
  if ( $yesorno eq 'y' ) {
    $tables{$name} = 1;
    if ( $tourney_running eq 1 ) {
      my $standup1 = shift(@stack);
      push @stack, $standup1;
      my $standup2 = shift(@stack);
      push @stack, $standup2;
      $players{$standup1}{'table'} = $name;
      $players{$standup2}{'table'} = $name;
    }
  } else {
    return
  } 
}

sub new_player {
  clear_screen();
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

  clear_screen();
  print "\nPlease choose number of player to delete:\n";
  my $num = 0;
  foreach(@players) {
    my $player = $_;
    $num++;
    print "$num: $player\n";
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

  clear_screen();
  print "\nPlease choose number of player to give chip:\n";
  my $num = 0;
  foreach(@players) {
    my $player = $_;
    $num++;
    print "$num: $player\n";
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

  clear_screen();
  print "\nPlease choose number of player to take chip:\n";
  my $num = 0;
  foreach(@players) {
    my $player = $_;
    $num++;
    print "$num: $player\n";
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
    if ( $players{$player}{'chips'} eq 0 ) {
      push @dead, "$player: $players{$player}{'won'}";
      delete $players{$player};
    }
    return;
  } else {
    return
  } 
}

sub delete_table {

  my @tables = keys(%tables);
  @tables = sort { $a <=> $b } (@tables);

  clear_screen();
  print "\nPlease choose number of table to delete:\n";
  my $num = 0;
  foreach(@tables) {
    my $table = $_;
    $num++;
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

  my @tempsplice;
  print "Delete table $table, correct?\n";
  my $yesorno = yesorno();
  chomp($yesorno);
  my $tempsplice;

  # If deleting a table in use move players to top of stack
  if ( $yesorno eq 'y' ) {
    delete $tables{$table};
    my @players = keys(%players);
    my $name;
    foreach (@players) {
      my $player = $_;
      if ( $players{$player}{'table'} eq $table ) {
        $players{$player}{'table'} = 'none';
        my $i = 0;
        foreach(@stack) {
          $name = $_;
	  $i++;
	  if ( $name eq $player ) {
            $i--;
	    $tempsplice = splice (@stack, $i, 1);
	    push @tempsplice, $tempsplice;
	  }
        }
      }
    }
    foreach(@tempsplice) {
      unshift @stack, $_;
    }
    return;
  } else {
    return
  } 
}

sub quit_program {
  clear_screen();
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
    if ( $^O =~ /next/ ) {
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
  clear_screen();
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
    sleep 2;
    print "Shuffled.\n";
    sleep 1;
  }
}
