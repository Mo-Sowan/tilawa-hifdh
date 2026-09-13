namespace Tilawa.Api.Models;

/// <summary>
/// One reciter following another on the leaderboard.
/// </summary>
/// <remarks>
/// <para>
/// Deliberately one-directional and unapproved: this is a leaderboard, not a
/// messaging system. Following someone reveals nothing that the global board
/// would not already show, so requiring them to accept would add a workflow
/// without adding any protection.
/// </para>
/// <para>
/// The pair is unique, so following twice is a no-op rather than a duplicate.
/// </para>
/// </remarks>
public sealed class Friendship
{
    public Guid Id { get; init; } = Guid.NewGuid();

    /// <summary>The account doing the following.</summary>
    public Guid UserId { get; init; }

    /// <summary>The account being followed.</summary>
    public Guid FriendUserId { get; init; }

    public DateTimeOffset CreatedAt { get; init; } = DateTimeOffset.UtcNow;
}
