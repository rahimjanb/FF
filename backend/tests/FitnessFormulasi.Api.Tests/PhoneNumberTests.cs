using FitnessFormulasi.Api.Common;

namespace FitnessFormulasi.Api.Tests;

public class PhoneNumberTests
{
    [Theory]
    [InlineData("+998 90 123-45-67", "+998901234567")]
    [InlineData("998901234567", "+998901234567")]
    [InlineData("90 123 45 67", "+998901234567")]
    [InlineData("(90) 1234567", "+998901234567")]
    [InlineData("+7 916 123 45 67", "+79161234567")]
    public void Normalizes_valid_numbers(string input, string expected) => Assert.Equal(expected, PhoneNumber.Normalize(input));

    [Theory]
    [InlineData("")]
    [InlineData("abc")]
    [InlineData("12345")]
    [InlineData("+99890123456")]
    [InlineData("+9989012345678")]
    public void Rejects_invalid_numbers(string input) => Assert.Null(PhoneNumber.Normalize(input));
}
