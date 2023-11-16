# Dense vs Spare arrays of expressions

This is a short test to see if there is a difference in performance between building expressions / structs as we loop through inputs or saving those inputs in a concise manner and then building large arrays of expressions all at once with a map between them.

# Results

The results suggest that there is not much difference between the approaches. Both results have very similar runtimes and memory usage. The dense approach consistently uses slightly less memory, but it's a very small difference. The sparse approach is slightly faster, but again, it's a very small difference.

However, one problem with this comparison is that the sparse approach should do other work between creating variables and expressions while the dense approach will not. By not including this, we may be giving the sparse approach an advantage.

I tried to introduce some busy work where the programme had to generate and sum random numbers. Both sets of actions were the same but it was concentrated at the beginning of the dense approach and within the sparse loop.

This created a difference between the two approaches, with the dense approach being slightly faster but using considerably less memory. It is not entirely clear to me why it's using less memory. It could be that the compiler is able to simplify the work when it is all done together, in the dense case.

# Conclusion

This test suggests it will be worth pursuing this concept further. I'm not entirely sold on it one way or another but it appears that doing all the prep work then all the variable and expression building is slightly faster and uses less memory. We should see if we can test further using real prep work, including file / IO access.
