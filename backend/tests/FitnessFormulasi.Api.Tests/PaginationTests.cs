using System.Net.Http.Json;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using FitnessFormulasi.Api.Features;
using FitnessFormulasi.Api.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace FitnessFormulasi.Api.Tests;

/// <summary>
/// Paging must return every record exactly once even when the sort key has ties
/// (rows saved in one transaction share CreatedAt; clients can share a name).
/// </summary>
[Collection(ApiCollection.Name)]
public class PaginationTests(ApiFactory factory)
{
    private readonly Scenario _s = new(factory);
    private static System.Text.Json.JsonSerializerOptions Json => ApiFactory.Json;

    private async Task WithDbAsync(Func<AppDbContext, Task> action)
    {
        using var scope = factory.Services.CreateScope();
        await action(scope.ServiceProvider.GetRequiredService<AppDbContext>());
    }

    /// <summary>Reads every page with a small page size and checks counts and paging metadata.</summary>
    private static async Task<List<T>> AllPagesAsync<T>(HttpClient http, string url, int pageSize, int expected)
    {
        var all = new List<T>();
        var sep = url.Contains('?') ? '&' : '?';
        for (var page = 1; ; page++)
        {
            var res = (await http.GetFromJsonAsync<PagedResult<T>>($"{url}{sep}page={page}&pageSize={pageSize}", Json))!;
            Assert.Equal(expected, res.TotalCount);
            if (res.Items.Count == 0) break;
            Assert.True(res.Items.Count <= pageSize);
            all.AddRange(res.Items);
        }
        Assert.Equal(expected, all.Count);
        return all;
    }

    [Fact]
    public async Task Client_history_pages_have_no_gaps_or_duplicates_with_equal_start_times()
    {
        var (trainer, t) = await _s.CreateTrainerAsync(await factory.AdminAsync());
        var (client, _) = await _s.RegisterClientAsync();
        var clientId = await _s.ClientIdAsync(client);
        var past = factory.Clock.Now.AddDays(-3);
        await WithDbAsync(async db =>
        {
            // 4 sessions share one start time, 3 more are older; statuses mix completed, cancelled and unmarked.
            for (var i = 0; i < 7; i++)
                db.TrainingSessions.Add(new TrainingSession
                {
                    TrainerProfileId = t.Id, ClientProfileId = clientId, DurationMinutes = 60,
                    StartsAt = i < 4 ? past : past.AddDays(-i),
                    Status = (TrainingSessionStatus)(i % 3),
                });
            await db.SaveChangesAsync();
        });

        var all = await AllPagesAsync<TrainingSessionDto>(client, "/api/me/training-sessions?scope=History", pageSize: 3, expected: 7);
        Assert.Equal(7, all.Select(s => s.Id).Distinct().Count());
        Assert.Equal(all.OrderByDescending(s => s.StartsAt).Select(s => s.StartsAt), all.Select(s => s.StartsAt));
        _ = trainer;
    }

    [Fact]
    public async Task Notifications_created_together_page_without_gaps_or_duplicates()
    {
        var (client, auth) = await _s.RegisterClientAsync();
        await WithDbAsync(async db =>
        {
            for (var i = 0; i < 9; i++)
                db.Notifications.Add(new Notification { UserId = auth.User.Id, Type = NotificationType.TrainingSessionScheduled });
            await db.SaveChangesAsync(); // one transaction: all rows get the same CreatedAt
        });

        var all = await AllPagesAsync<NotificationDto>(client, "/api/notifications", pageSize: 4, expected: 9);
        Assert.Equal(9, all.Select(n => n.Id).Distinct().Count());
    }

    [Fact]
    public async Task Trainer_clients_with_identical_names_page_without_gaps_or_duplicates()
    {
        var (trainer, t) = await _s.CreateTrainerAsync(await factory.AdminAsync());
        var ids = new List<Guid>();
        for (var i = 0; i < 5; i++)
            ids.Add(await _s.ClientIdAsync((await _s.RegisterClientAsync()).Http));
        await WithDbAsync(async db =>
        {
            foreach (var c in await db.ClientProfiles.Include(c => c.User).Where(c => ids.Contains(c.Id)).ToListAsync())
            {
                c.AssignedTrainerId = t.Id;
                c.User.FirstName = "Same";
                c.User.LastName = "Name";
            }
            await db.SaveChangesAsync();
        });

        var all = await AllPagesAsync<TrainerClientDto>(trainer, "/api/trainer/clients", pageSize: 2, expected: 5);
        Assert.Equal(ids.Order(), all.Select(c => c.Id).Order());
    }
}
