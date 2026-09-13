using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.ChangeTracking;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;
using Tilawa.Api.Models;

namespace Tilawa.Api.Data;

/// <summary>
/// EF Core context for the Tilawa API.
/// </summary>
/// <remarks>
/// Every per-user table is keyed by <c>UserId</c>, and the surah catalogue is
/// a separate shared table, so one deployment serves many accounts without
/// duplicating the 114 static rows per user.
/// </remarks>
public class TilawaDbContext : DbContext
{
    public TilawaDbContext(DbContextOptions<TilawaDbContext> options) : base(options) { }

    public DbSet<User> Users => Set<User>();

    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();

    public DbSet<Surah> Surahs => Set<Surah>();

    public DbSet<UserSurahProgress> UserSurahProgress => Set<UserSurahProgress>();

    public DbSet<RevisionPlan> RevisionPlans => Set<RevisionPlan>();

    public DbSet<ActivityDay> ActivityDays => Set<ActivityDay>();

    public DbSet<RecitationSession> RecitationSessions => Set<RecitationSession>();

    public DbSet<ReciterProfile> ReciterProfiles => Set<ReciterProfile>();

    public DbSet<Friendship> Friendships => Set<Friendship>();

    /// <summary>
    /// Stores every <see cref="DateTimeOffset"/> as UTC ticks.
    /// </summary>
    /// <remarks>
    /// SQLite cannot order or compare its default textual representation, so
    /// queries like "most recent sessions first" fail to translate. Ticks sort
    /// and compare natively. Everything the API records is UTC, so collapsing
    /// the offset loses nothing.
    /// </remarks>
    protected override void ConfigureConventions(ModelConfigurationBuilder configurationBuilder)
    {
        base.ConfigureConventions(configurationBuilder);

        configurationBuilder.Properties<DateTimeOffset>()
            .HaveConversion<DateTimeOffsetToTicksConverter>();
        configurationBuilder.Properties<DateTimeOffset?>()
            .HaveConversion<NullableDateTimeOffsetToTicksConverter>();
    }

    private sealed class DateTimeOffsetToTicksConverter
        : ValueConverter<DateTimeOffset, long>
    {
        public DateTimeOffsetToTicksConverter()
            : base(
                value => value.UtcTicks,
                ticks => new DateTimeOffset(ticks, TimeSpan.Zero))
        {
        }
    }

    private sealed class NullableDateTimeOffsetToTicksConverter
        : ValueConverter<DateTimeOffset?, long?>
    {
        public NullableDateTimeOffsetToTicksConverter()
            : base(
                value => value == null ? null : value.Value.UtcTicks,
                ticks => ticks == null
                    ? null
                    : new DateTimeOffset(ticks.Value, TimeSpan.Zero))
        {
        }
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        var intSetComparer = new ValueComparer<HashSet<int>>(
            (left, right) => left != null && right != null ? left.SetEquals(right) : left == right,
            values => values == null ? 0 : values.OrderBy(v => v).Aggregate(0, HashCode.Combine),
            values => values == null ? new HashSet<int>() : values.ToHashSet());

        var stringListComparer = new ValueComparer<List<string>>(
            (left, right) => left != null && right != null ? left.SequenceEqual(right) : left == right,
            values => values == null ? 0 : values.Aggregate(0, (hash, v) => HashCode.Combine(hash, v.GetHashCode())),
            values => values == null ? new List<string>() : values.ToList());

        modelBuilder.Entity<User>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.ProviderSubject).IsRequired();
            // One account per (provider, subject): re-signing in must find the
            // existing user rather than create a duplicate.
            entity.HasIndex(e => new { e.Provider, e.ProviderSubject }).IsUnique();
        });

        modelBuilder.Entity<ReciterProfile>(entity =>
        {
            // One profile per account, keyed by the account itself: there is
            // never a second set of answers for the same person.
            entity.HasKey(e => e.UserId);
            entity.HasOne<User>()
                .WithOne()
                .HasForeignKey<ReciterProfile>(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Friendship>(entity =>
        {
            entity.HasKey(e => e.Id);
            // Following the same person twice is meaningless, so the pair is
            // the real key and the index enforces it.
            entity.HasIndex(e => new { e.UserId, e.FriendUserId }).IsUnique();
            entity.HasOne<User>()
                .WithMany()
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<User>()
                .WithMany()
                .HasForeignKey(e => e.FriendUserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<RefreshToken>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.TokenHash).IsUnique();
            entity.HasIndex(e => e.UserId);
            entity.HasOne<User>()
                .WithMany()
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Surah>(entity =>
        {
            entity.HasKey(e => e.Number);
            entity.Property(e => e.Number).ValueGeneratedNever();
            entity.HasData(
                SurahCatalog.All.Select(entry => new Surah
                {
                    Number = entry.Number,
                    EnglishName = entry.EnglishName,
                    ArabicName = entry.ArabicName,
                    JuzLabel = entry.JuzLabel,
                    AyahCount = entry.AyahCount,
                }));
        });

        modelBuilder.Entity<UserSurahProgress>(entity =>
        {
            entity.HasKey(e => new { e.UserId, e.SurahNumber });
            entity.HasOne<User>()
                .WithMany()
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<Surah>()
                .WithMany()
                .HasForeignKey(e => e.SurahNumber)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<RevisionPlan>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.UserId);
            entity.HasOne<User>()
                .WithMany()
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.Property(e => e.SurahNumbers)
                .HasConversion(
                    v => JsonSerializer.Serialize(v, (JsonSerializerOptions?)null),
                    v => JsonSerializer.Deserialize<HashSet<int>>(v, (JsonSerializerOptions?)null) ?? new HashSet<int>())
                .Metadata.SetValueComparer(intSetComparer);
        });

        modelBuilder.Entity<ActivityDay>(entity =>
        {
            entity.HasKey(e => new { e.UserId, e.Date });
            entity.HasOne<User>()
                .WithMany()
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.Property(e => e.SurahNumbers)
                .HasConversion(
                    v => JsonSerializer.Serialize(v, (JsonSerializerOptions?)null),
                    v => JsonSerializer.Deserialize<HashSet<int>>(v, (JsonSerializerOptions?)null) ?? new HashSet<int>())
                .Metadata.SetValueComparer(intSetComparer);
        });

        modelBuilder.Entity<RecitationSession>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => new { e.UserId, e.StartedAt });
            entity.HasOne<User>()
                .WithMany()
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.Property(e => e.CoveredRefs)
                .HasConversion(
                    v => JsonSerializer.Serialize(v, (JsonSerializerOptions?)null),
                    v => JsonSerializer.Deserialize<List<string>>(v, (JsonSerializerOptions?)null) ?? new List<string>())
                .Metadata.SetValueComparer(stringListComparer);
        });
    }
}
