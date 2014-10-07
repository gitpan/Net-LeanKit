package Net::LeanKit;
$Net::LeanKit::VERSION = '0.5';
# ABSTRACT: A perl library for Leankit.com

use strict;
use warnings;
use Carp;
use HTTP::Tiny;
use JSON::Any;
use URI::Escape;


use Class::Tiny qw( email password account ), {
    boardIdentifiers => sub { +{} },
    defaultWipOverrideReason =>
      sub {'WIP Override performed by external system'},
    headers => sub {
        {   'Accept'       => 'application/json',
            'Content-type' => 'application/json'
        };
    },
    ua => sub { HTTP::Tiny->new },
    j  => sub { JSON::Any->new }
};

sub BUILD {
    my ($self, $args) = @_;
    for my $req (qw/ email password account/) {
        croak "$req attribute required" unless defined $self->$req;
    }
}



sub get {
    my ($self, $endpoint) = @_;
    my $auth = uri_escape(sprintf("%s:%s", $self->email, $self->password));
    my $url = sprintf('https://%s@%s.leankit.com/kanban/api/%s',
        $auth, $self->account, $endpoint);

    my $r = $self->ua->get($url, {headers => $self->headers});
    croak "$r->{status} $r->{reason}" unless $r->{success};
    my $content = $r->{content} ? $self->j->decode($r->{content}) : +[];
    return $content->{ReplyData}->[0];
}


sub post {
    my ($self, $endpoint, $body) = @_;
    my $auth = uri_escape(sprintf("%s:%s", $self->email, $self->password));
    my $url = sprintf('https://%s@%s.leankit.com/kanban/api/%s',
        $auth, $self->account, $endpoint);

    my $post = {headers => $self->headers};
    if (defined $body) {
        $post->{content} = $self->j->encode($body);
    }
    else {
        $post->{headers}->{'Content-Length'} = '0';
    }
    my $r = $self->ua->post($url, $post);
    croak "$r->{status} $r->{reason}" unless $r->{success};
    my $content = $r->{content} ? $self->j->decode($r->{content}) : +[];
    return $content->{ReplyData}->[0];
}



sub getBoards {
    my ($self) = @_;
    return $self->get('boards');
}



sub getNewBoards {
    my ($self) = @_;
    return $self->get('ListNewBoards');
}


sub getBoard {
    my ($self, $id) = @_;
    my $boardId = sprintf('boards/%s', $id);
    return $self->get($boardId);
}



sub getBoardByName {
    my ($self, $boardName) = @_;
    foreach my $board (@{$self->getBoards}) {
        next unless $board->{Title} =~ /$boardName/i;
        return $board;
    }
}


sub getBoardIdentifiers {
    my ($self, $boardId) = @_;

    # use cache
    if ($self->boardIdentifiers->{$boardId}) {
        return $self->boardIdentifiers->{$boardId};
    }

    my $board = sprintf('board/%s/GetBoardIdentifiers', $boardId);
    my $data = $self->get($board);
    $self->boardIdentifiers->{$boardId} = $data;
    return $self->boardIdentifiers->{$boardId};
}


sub getBoardBacklogLanes {
    my ($self, $boardId) = @_;
    my $board = sprintf("board/%s/backlog", $boardId);
    return $self->get($board);
}


sub getBoardArchiveLanes {
    my ($self, $boardId) = @_;
    my $board = sprintf("board/%s/archive", $boardId);
    return $self->get($board);
}


sub getBoardArchiveCards {
    my ($self, $boardId) = @_;
    my $board = sprintf("board/%s/archivecards", $boardId);
    return $self->get($board);
}


sub getNewerIfExists {
    my ($self, $boardId, $version) = @_;
    my $board = sprintf("board/%s/boardversion/%s/getnewerifexists", $boardId,
        $version);
    return $self->get($board);
}


sub getBoardHistorySince {
    my ($self, $boardId, $version) = @_;
    my $board = sprintf("board/%s/boardversion/%s/getboardhistorysince",
        $boardId, $version);
    return $self->get($board);
}


sub getBoardUpdates {
    my ($self, $boardId, $version) = @_;
    my $board =
      sprintf("board/%s/boardversion/%s/checkforupdates", $boardId, $version);
    return $self->get($board);
}


sub getCard {
    my ($self, $boardId, $cardId) = @_;
    my $board = sprintf("board/%s/getcard/%s", $boardId, $cardId);
    return $self->get($board);
}


sub getCardByExternalId {
    my ($self, $boardId, $externalCardId) = @_;
    my $board = sprintf("board/%s/getcardbyexternalid/%s",
        $boardId, uri_escape($externalCardId));
    return $self->get($board);
}



sub addCard {
    my ($self, $boardId, $laneId, $position, $card) = @_;
    $card->{UserWipOverrideComment} = $self->defaultWipOverrideReason;
    my $newCard =
      sprintf('board/%s/AddCardWithWipOverride/Lane/%s/Position/%s',
        $boardId, $laneId, $position);
    return $self->post($newCard, $card);
}


sub addCards {
    my ($self, $boardId, $cards) = @_;
    my $newCard =
      sprintf('board/%s/AddCards?wipOverrideComment="%s"',
        $boardId, $self->defaultWipOverrideReason);
    return $self->post($newCard, $cards);
}



sub moveCard {
    my ($self, $boardId, $cardId, $toLaneId, $position) = @_;
    my $moveCard =
      sprintf('board/%s/movecardwithwipoverride/%s/lane/%s/position/%s',
        $boardId, $cardId, $toLaneId, $position);
    my $params = {comment => $self->defaultWipOverrideReason};
    return $self->post($moveCard, $params);
}



sub moveCardByExternalId {
    my ($self, $boardId, $externalCardId, $toLaneId, $position) = @_;
    my $moveCard = sprintf(
        'board/%s/movecardbyexternalid/%s/lane/%s/position/%s',
        $boardId, uri_escape($externalCardId),
        $toLaneId, $position
    );
    my $params = {comment => $self->defaultWipOverrideReason};
    return $self->post($moveCard, $params);
}



sub moveCardToBoard {
    my ($self, $cardId, $destinationBoardId) = @_;
    my $moveCard = sprintf('card/movecardtoanotherboard/%s/%s',
        $cardId, $destinationBoardId);
    my $params = {};
    return $self->post($moveCard, $params);
}



sub updateCard {
    my ($self, $boardId, $card) = @_;
    $card->{UserWipOverrideComment} = $self->defaultWipOverrideReason;
    my $updateCard = sprintf('board/%s/UpdateCardWithWipOverride');
    return $self->post($updateCard, $card);
}

sub updateCardFields {
  my ($self, $updateFields) = @_;
  return $self->post('card/update', $updateFields);
}

sub getComments {
  my ($self, $boardId, $cardId) = @_;
  my $comment = sprintf('card/getcomments/%s/%s', $boardId, $cardId);
  return $self->get($comment);
}

sub addComment {
    my ($self, $boardId, $cardId, $userId, $comment) = @_;
    my $params = {PostedById => $userId, Text => $comment};
    my $addComment = sprintf('card/savecomment/%s/%s', $boardId, $cardId);
    return $self->post($addComment, $params);
}


sub addCommentByExternalId {
    my ($self, $boardId, $externalCardId, $userId, $comment) = @_;
    my $params = {PostedById => $userId, Text => $comment};
    my $addComment = sprintf('card/savecommentbyexternalid/%s/%s',
        $boardId, uri_escape($externalCardId));
    return $self->post($addComment, $params);
}

sub getCardHistory {
  my ($self, $boardId, $cardId) = @_;
  my $history = sprintf('card/history/%s/%s', $boardId, $cardId);
  return $self->get($history);
}



sub searchCards {
    my ($self, $boardId, $options) = @_;
    my $search = sprintf('board/%s/searchcards', $boardId);
    return $self->post($search, $options);
}

sub getNewCards {
    my ($self, $boardId) = @_;
    my $newCards = sprintf('board/%s/listnewcards', $boardId);
    return $self->get($newCards);
}

sub deleteCard {
    my ($self, $boardId, $cardId) = @_;
    my $delCard = sprintf('board/%s/deletecard/%s', $boardId, $cardId);
    return $self->post($delCard, {});
}

sub deleteCards {
    my ($self, $boardId, $cardIds) = @_;
    my $delCard = sprintf('board/%s/deletecards', $boardId);
    return $self->post($delCard, $cardIds);
}

sub getTaskBoard {
    my ($self, $boardId, $cardId) = @_;
    my $taskBoard =
      sprintf('v1/board/%s/card/%s/taskboard', $boardId, $cardId);
    return $self->get($taskBoard);
}

sub addTask {
    my ($self, $boardId, $cardId, $taskCard) = @_;
    $taskCard->{UserWipOverrideComment} = $self->defaultWipOverrideReason;
    my $url = sprintf('v1/board/%s/card/%s/tasks/lane/%s/position/%s',
        $boardId, $cardId, $taskCard->{LaneId}, $taskCard->{Index});
    return $self->post($url, $taskCard);
}

sub updateTask {
    my ($self, $boardId, $cardId, $taskCard) = @_;
    $taskCard->{UserWipOverrideComment} = $self->defaultWipOverrideReason;
    my $url = sprintf('v1/board/%s/update/card/%s/tasks/%s',
        $boardId, $cardId, $taskCard->{Id});
    return $self->post($url, $taskCard);
}

sub deleteTask {
    my ($self, $boardId, $cardId, $taskId) = @_;
    my $url = sprintf('v1/board/%s/delete/card/%s/tasks/%s',
        $boardId, $cardId, $taskId);
    return $self->post($url, {});
}

sub getTaskBoardUpdates {
    my ($self, $boardId, $cardId, $version) = @_;
    my $url = sprintf('v1/board/%s/card/%s/tasks/boardversion/%s',
        $boardId, $cardId, $version);
    return $self->get($url);
}

sub moveTask {
    my ($self, $boardId, $cardId, $taskId, $toLaneId, $position) = @_;
    my $url = sprintf('v1/board/%s/move/card/%s/tasks/%s/lane/%s/position/%s',
        $boardId, $cardId, $taskId, $toLaneId, $position);
    return $self->post($url, {});
}

sub getAttachmentCount {
  my ($self, $boardId, $cardId) = @_;
  my $url = sprintf('card/GetAttachmentsCount/%s/%s', $boardId, $cardId);
  return $self->get($url);
}

sub getAttachments {
  my ($self, $boardId, $cardId) = @_;
  my $url = sprintf('card/GetAttachments/%s/%s', $boardId, $cardId);
  return $self->get($url);
}

sub getAttachment {
  my ($self, $boardId, $cardId, $attachmentId) = @_;
  my $url = sprintf('card/GetAttachments/%s/%s/%s', $boardId, $cardId, $attachmentId);
  return $self->get($url);
}

sub downloadAttachment {
  my $self = shift;
  return 'Not implemented';
}

sub deleteAttachment {
  my ($self, $boardId, $cardId, $attachmentId) = @_;
  my $url = sprintf('card/DeleteAttachment/%s/%s/%s', $boardId, $cardId, $attachmentId);
  return $self->post($url, {});
}

sub addAttachment {
  my $self = shift;
  return 'Not Implemented';
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Net::LeanKit - A perl library for Leankit.com

=head1 VERSION

version 0.5

=head1 SYNOPSIS

  use Net::LeanKit;
  my $lk = Net::LeanKit(email => 'user\@.mail.com',
                        password => 'pass',
                        account => 'my company');
  $lk->getBoards;

=head1 ATTRIBUTES

=head2 email

Login email

=head2 password

Password

=head2 account

Account name in which your account is under, usually a company name.

=head1 METHODS

=head2 get

GET requests to leankit

=head2 post

POST requests to leankit

=head2 getBoards

Returns list of boards

=head2 getNewBoards

Returns list of latest created boards

=head2 getBoard

Gets leankit board by id

=head2 getBoardByName

Finds a board by name

=head2 getBoardIdentifiers

Get board identifiers

=head2 getBoardBacklogLanes

Get board back log lanes

=head2 getBoardArchiveLanes

Get board archive lanes

=head2 getBoardArchiveCards

Get board archive cards

=head2 getNewerIfExists

Get newer board version if exists

=head2 getBoardHistorySince

Get newer board history

=head2 getBoardUpdates

Get board updates

=head2 getCard

Get specific card for board

=head2 getCardByExternalId

Get specific card for board by an external id

=head2 addCard

Add a card to the board/lane specified. The card hash usually contains

  { TypeId => 1,
    Title => 'my card title',
    ExternalCardId => DATETIME,
    Priority => 1
  }

=head2 addCards

Add multiple cards to the board/lane specified. The card hash usually contains

  { TypeId => 1,
    Title => 'my card title',
    ExternCardId => DATETIME,
    Priority => 1
  }

=head2 moveCard

Moves card to different lanes

=head2 moveCardByExternalId

Moves card to different lanes by externalId

=head2 moveCardToBoard

Moves card to another board

=head2 updateCard

Update a card

=head2 updateCardFields

Update fields in card

=head2 getComments

Get comments for card

=head2 addComment

Add comment for card

=head2 addCommentByExternalId

Add comment for card

=head2 getCardHistory

Get card history

=head2 searchCards

Search cards, options is a hashref of search options

Eg,

    searchOptions = {
        IncludeArchiveOnly: false,
        IncludeBacklogOnly: false,
        IncludeComments: false,
        IncludeDescription: false,
        IncludeExternalId: false,
        IncludeTags: false,
        AddedAfter: null,
        AddedBefore: null,
        CardTypeIds: [],
        ClassOfServiceIds: [],
        Page: 1,
        MaxResults: 20,
        OrderBy: "CreatedOn",
        SortOrder: 0
    };

=head2 getNewCards

Get latest added cards

=head2 deleteCard

Delete a single card

=head2 deleteCards

Delete batch of cards

=head2 getTaskBoard

Get task board

=head2 addTask

Adds task to card

=head2 updateTask

Updates task in card

=head2 deleteTask

Deletes task

=head2 getTaskBoardUpdates

Get latest task additions/changes

=head2 moveTask

Moves task to different lanes

=head2 getAttachmentCount

Get num of attachments for card

=head2 getAttachments

Get list of attachments

=head2 getAttachment

Get single attachment

=head2 deleteAttachment

Removes attachment from card

=head1 AUTHOR

Adam Stokes <adamjs@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Adam Stokes.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT
WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER
PARTIES PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND,
EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE. THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE
SOFTWARE IS WITH YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME
THE COST OF ALL NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE LIABLE
TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THE
SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH
DAMAGES.

=cut
