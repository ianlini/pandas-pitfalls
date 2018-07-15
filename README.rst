
Pandas Pitfalls
===============

Pandas is a popular package in Python. If you are a data scientist using
Python, you definitely are using Pandas. However, do you really
understand how pandas works? If not, you will have a lot of performance
issues. In this notebook, I will use a magical example to illustrate how
Pandas works. You will at least understand how to trace the behavior of
Pandas after reading this. I also have
`slides <https://hackmd.io/p/rJkXzTWm7#/>`__ talking about this.

Run this notebook
-----------------

Generate README
---------------

Problem 1
---------

.. code:: ipython3

    import numpy as np
    import pandas as pd

Guess the time of each line
~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code:: ipython3

    rs = np.random.RandomState(1126)
    %time df = pd.DataFrame(rs.randint(200, size=(500000, 200)), dtype=np.float64)
    %time new_s = df.loc[:, 0].astype(np.int16)
    %time df.loc[:, 0] = new_s


.. parsed-literal::

    CPU times: user 1.25 s, sys: 488 ms, total: 1.73 s
    Wall time: 1.76 s
    CPU times: user 3.76 ms, sys: 7.94 ms, total: 11.7 ms
    Wall time: 11.4 ms
    CPU times: user 1.16 s, sys: 236 ms, total: 1.39 s
    Wall time: 1.4 s


-  the assignment is supprisingly slow!

Let’s run again
~~~~~~~~~~~~~~~

.. code:: ipython3

    %time df = pd.DataFrame(rs.randint(200, size=(500000, 200)), dtype=np.float64)
    %time new_s = df.loc[:, 0].astype(np.int16)
    %time df.loc[:, 0] = new_s


.. parsed-literal::

    CPU times: user 1.28 s, sys: 488 ms, total: 1.76 s
    Wall time: 1.78 s
    CPU times: user 9 ms, sys: 0 ns, total: 9 ms
    Wall time: 8.53 ms
    CPU times: user 1.16 s, sys: 236 ms, total: 1.4 s
    Wall time: 1.4 s


-  the result is still similar

Tracing the issue
~~~~~~~~~~~~~~~~~

-  ``pandas.core.internals``: 6000 lines of code in one file
-  the magical ``BlockManager`` mainly controls how pandas deals with
   memory
-  ``df._data`` is the ``BlockManager`` of ``df``
-  we can observe the behavior by watching ``df._data.blocks``

.. code:: ipython3

    df = pd.DataFrame(rs.randint(200, size=(500000, 200)), dtype=np.float64)
    df._data.blocks




.. parsed-literal::

    (FloatBlock: slice(0, 200, 1), 200 x 500000, dtype: float64,)



.. code:: ipython3

    df.loc[:, 0] = df.loc[:, 0].astype(np.int16)
    df._data.blocks




.. parsed-literal::

    (FloatBlock: slice(1, 200, 1), 199 x 500000, dtype: float64,
     IntBlock: slice(0, 1, 1), 1 x 500000, dtype: int16)



So why is this slow?
~~~~~~~~~~~~~~~~~~~~

After some profiling and tracing, we can find that:

-  each block maintains an ``np.ndarray`` (#cols x #rows)
-  ``BlockManager`` calls ``np.delete`` to delete one row in
   ``FloatBlock``
-  when we assign the column, 98.46% of time is used to do the deletion
-  ``np.delete`` copy the whole ``np.ndarray`` except the deleted row to
   a new ``np.ndarray``

Why does pandas do this?
~~~~~~~~~~~~~~~~~~~~~~~~

-  explained in the `pandas 2.0 design
   docs <https://pandas-dev.github.io/pandas2/internal-architecture.html#removal-of-blockmanager-new-dataframe-internals>`__

   -  ancient pandas history
   -  they wanted to rely on ``numpy``, and contiguous memory access
      produces much better performance in ``numpy``
   -  so they use ``BlockManager`` to maintain severy contiguous memory
      blocks
   -  pandas developers want to replace ``BlockManager`` using native
      C/C++ code and design a new algorithm that won’t have this kind of
      magical problems

-  currently

   -  pandas is designed for those fast operations
   -  **pandas is not designed to frequently change the sizes or types
      of the blocks**

Extended observation
~~~~~~~~~~~~~~~~~~~~

Based our previous observation, we can explore more about the magical
behavior.

Try your best to guess the result of the following code:

.. code:: ipython3

    df.loc[:, 3] = df.loc[:, 3].astype(np.int16)
    df._data.blocks




.. parsed-literal::

    (FloatBlock: [1, 2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, ...], 198 x 500000, dtype: float64,
     IntBlock: slice(0, 1, 1), 1 x 500000, dtype: int16,
     IntBlock: slice(3, 4, 1), 1 x 500000, dtype: int16)



.. code:: ipython3

    df.loc[:, 3] = df.loc[:, 3].astype(np.float64)
    df._data.blocks




.. parsed-literal::

    (FloatBlock: [1, 2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, ...], 198 x 500000, dtype: float64,
     IntBlock: slice(0, 1, 1), 1 x 500000, dtype: int16,
     FloatBlock: slice(3, 4, 1), 1 x 500000, dtype: float64)



-  after changing the type of a column, the next type changing should be
   very fast

Other problems
--------------

-  What happens when you append a row to a ``DataFrame``?
-  What happens when you add a column to a ``DataFrame``?
-  How about 1-d arrays (``Series`` and ``Index``)?
