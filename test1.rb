# Recursive Factorial
sum = 0
# Complete the following
def factorial(n)
  return 1 if n <= 1
  sum = n * (factorial(n - 1))
  return sum
end

def main
  n = gets.chomp.to_i
  if n < 1 
    puts("Incorrect argument - need a single argument with a value of 0 or more.\n")
  else
    puts(factorial(n))
  end
end

main