"""
Provides routines for reducing a collection of cells via similarity metrics.
"""

from . import potential
from . import crystal
import numpy
import copy

def reduce(cells, metric):
    """
    Reduces cells using the specified metric. Retains the lowest energy candidate
    of all those that are "similar" to one another according to the metric.

    Parameters
    ----------
    cells : iterable(tuple(paccs.crystal.Cell, float))
        Cells with their energies, most likely generated by
        :py:func:`ResultsDatabase.cells`.
    metric : SimilarityMetric
        A predefined similarity metric, or a custom function
        accepting two members of the **cells** iterable and
        returning a boolean indicating similarity or lack
        thereof.

    Returns
    -------
    list(tuple(paccs.crystal.Cell, float))
        The reduced collection of cells.  In each case that
        two or more cells are considered similar to each
        other, the cells with the lowest energies will always
        be retained.
    """

    result = []
    # Work from the lowest energy cell to the highest
    for cell in sorted(cells, key=lambda cell: cell[1]):
        for result_cell in result:
            # If a match is found, a lower energy cell similar to
            # this one is already present in the results list
            if metric(cell, result_cell):
                break
        else:
            # No match was found; add this cell to the list
            result.append(cell)
    return result

class Minkowski:
    r"""
    Creates a normalized :math:`L^p` norm:

    .. math:: \hat{f}(\vec x)={\left(\frac{1}{N}\sum_{i=1}^{N}x_i^p\right)}^{1/p}

    Unlike a proper Minkowski distance, this has been normalized to be bounded
    between 0 and 1 for convenient similarity checking. This assumes all
    components of the input vector are equally weighted and are bounded by unity.
    For example,

    .. math:: \hat{f} = \frac{f}{f^{\rm max}} = \left( \frac{\sum_{i=1}^N x_i^p}{\sum_{i=1}^N (x_i^{\rm max})^p} \right)^{1/p}.

    Assuming that for all components :math:`x_i^{\rm max} = K`, then

    .. math:: \hat{f} = \left( \frac{\sum_{i=1}^N x_i^p}{N K^p} \right)^{1/p}.

    If :math:`K = 1`, then

    .. math:: \hat{f} = \left( \frac{1}{N} \sum_{i=1}^N x_i^p \right)^{1/p}.

    Note that when :math:`p < 1`, the result fails the triangle inequality and this cannot be a *formal* `metric <https://en.wikipedia.org/wiki/Metric_(mathematics)>`_, so we recommend avoiding this case.

    Parameters
    ----------
    coefficient : float
        The value of :math:`p`.
    """

    def __init__(self, coefficient):
        self.__coefficient = coefficient

    def __call__(self, data):
        return numpy.sum((data ** self.__coefficient) / data.shape[0]) ** (1.0 / self.__coefficient)

class Manhattan(Minkowski):
    """
    Creates a normalized :math:`L^1` norm. See :py:class:`paccs.similarity.Minkowski`.
    """

    def __init__(self):
        super().__init__(1.0)

class Euclidean(Minkowski):
    """
    Creates a normalized :math:`L^2` norm. See :py:class:`paccs.similarity.Minkowski`.
    """

    def __init__(self):
        super().__init__(2.0)

class Minimum:
    """
    Creates the :math:`L^{-\infty}` norm which returns the minimum component in a vector.
    There is no "normalization" done here so be aware the output is not bounded
    between 0 and 1 automatically; this assumes the input is to be consistent
    with the usage pattern of :py:class:`paccs.similarity.Minkowski`.
    """

    def __init__(self): pass

    def __call__(self, data): return numpy.min(data)

class SimilarityMetric:
    r"""
    Represents an arbitrary similarity metric to determine the similarity of two
    configurations (:py:class:`paccs.crystal.Cell` objects).

    Notes
    -----
    It is best to use proper mathematic `metrics <https://en.wikipedia.org/wiki/Metric_(mathematics)>`_ to quantify similarity as
    they can be used in dimensionality reduction or machine learning, which require
    relative distance preservation (ordering) during projection to be meaningful.
    Metrics satisfy four properties:

    1. Non-negative, or separation axiom: :math:`d(x,y) \ge 0`
    2. Symmetry axiom: :math:`d(x,y) = d(y,x)`
    3. Identity axiom: :math:`d(x,y) = 0` if and only if x and y are idential
    4. Subadditivity axiom, or Triangle Inequality: :math:`d(x,z) \le d(x,y) + d(y,z)`

    Generally, a configurational "fingerprint" is established as an identifier for a structure,
    then some mathematical operation performed to measure the distance between the
    two for a pair of structures in order to determine their distance or (dis)similarity.
    A fingerprint should be `invariant to symmetries of the Hamiltonian <http://dx.doi.org/10.1021/acs.jctc.7b00543>`_.
    For most fingerprint operations, the first two axioms are trivial to demonstrate,
    but the third and fourth are important to preserve (usually).

    Third (Identity) Axiom:
    In order for a fingerprint vector to `uniquely represent a configuration <http://dx.doi.org/10.1063/1.4828704>`_, it must
    be longer than the number of degrees of freedom, :math:`D`, in a system.  For example,
    in a d-dimensional system with :math:`N` particles, we should have :math:`D = dN - d \le L`,
    where :math:`L` is the length of the fingerprint vector.

    Fourth (Subadditivity) Axiom:
    One convenient operation that satisfies the fourth axiom is taking the `norm of a vector <http://mathworld.wolfram.com/VectorNorm.html>`_.
    The norm operation also satisfies fist axiom as part of its definition.
    This includes any :math:`L^p` norm where :math:`p \ge 1` (see :py:class:`paccs.similarity.Minkowski`).

    Convenient fingerprints which satisfy these properties are often derived from
    radial distribution functions, since they are radially symmetric and ivariant
    under `translation, rotation and the choice of unit cell <http://dx.doi.org/10.1103/PhysRevB.89.205118>`_.
    For example, see `Oganov and Valle <http://aip.scitation.org/doi/abs/10.1063/1.3079326>`_
    or `Schuett et al. <http://dx.doi.org/10.1103/PhysRevB.89.205118>`__. Eigenvalues of
    various pairwise matrices may also be used (and `may be generally better
    <http://dx.doi.org/10.1063/1.4828704>`_), but are more expensive to compute.
    See `Sadeghi et al. JCP (2013) <http://dx.doi.org/10.1063/1.4828704>`_,
    `Schuett et al. PRB (2014) <http://dx.doi.org/10.1103/PhysRevB.89.205118>`__, and
    `Griffiths et al. JCTC (2017) <http://dx.doi.org/10.1021/acs.jctc.7b00543>`_
    for more information.

    There are many examples of different such metrics provided here, however, the
    user should take care to **use radial distribution functions with enough bins to
    easily satisfy the Identity axiom**.  In general, the upper bound for the radial
    distribution functions should extend through the primitive cell (P.C.), beyond which
    all other positions are fixed by translation operations of the P.C. (recall that
    the P.C. has :math:`{\rm p1}` symmetry). Consequently, no particles beyond the P.C. strictly
    need to be considered to provide a unique fingerprint for the configuration
    since the other partices do not represent independent degrees of freedom.
    The inclusion of them, however, is not necessarily detrimental.
    """

    def __init__(self):
        self.__cache = {}

    def _compute_direct(self, cell):
        """
        Performs a direct computation of some quantity associated
        with a cell.
        """

        raise NotImplementedError

    def _compute_cached(self, cell):
        """
        Performs a computation of some quantity associated with a
        cell, checking an internal cache for the quantity.  This may
        be useful if an expensive calculation must be performed per
        cell, but not per pair.
        """

        if cell not in self.__cache:
            self.__cache[cell] = self._compute_direct(cell)

        return self.__cache[cell]

class Hybrid(SimilarityMetric):
    """
    Compares cells with a number of metrics or measures.  Uses short-circuiting
    to improve performance.  This can be useful if a fast metric or measure is
    provided followed by a slow metric or measure.

    Parameters
    ----------
    short_to : bool
        The short-circuiting default.  If False, behaves like a
        logical AND operation: the first metric or measure evaluating to False will
        cause this metric or measure to return False.  Similarly, if True, behaves
        like a logical OR operation.
    metrics: tuple(callable)
        The metrics themselves, in the desired order of evaluation.
    """

    def __init__(self, short_to, *metrics):
        super(Hybrid, self).__init__()
        self.__short_to = short_to
        self.__metrics = metrics

    def __call__(self, cell_1, cell_2):
        """
        Parameters
        ----------
        cell_1 : tuple(paccs.crystal.Cell, float)
           Cell with its energy, most likely generated by
           :py:func:`ResultsDatabase.cells`.
        cell_2 : tuple(paccs.crystal.Cell, float)
           Cell with its energy, most likely generated by
           :py:func:`ResultsDatabase.cells`.

        Returns
        -------
        bool
            Are the two cells "the same"?
        """

        for metric in self.__metrics:
            if metric(cell_1, cell_2) == self.__short_to:
                return self.__short_to
        return not self.__short_to

    def compute(self, cell_1, cell_2):
        """
        Parameters
        ----------
        cell_1 : paccs.crystal.Cell
            First cell to consider.
        cell_2 : paccs.crystal.Cell
            Second cell to consider.

        Returns
        -------
        float
            If short_to = False, returns similarity value from metric furthest below its threshold.  
            If short_to = True, returns similarity value from metric furthest above its threshold.
        """
        sim = []
        for metric in self.__metrics:
            sim.append((metric.compute(cell_1, cell_2), metric.threshold))
        sim = sorted(sim, key=lambda x:x[0]-x[1])
        if (self.__short_to):
            return sim[-1][0]
        else:
            return sim[0][0]

class Energy(SimilarityMetric):
    """
    Compares cells by directly comparing their energies.
    This is a measure not a metric.

    Parameters
    ----------
    threshold : float
        The absolute energy value (per particle, usually) used as a cutoff.  Cells
        whose energies differ by more than this value will
        be considered different.
    """

    def __init__(self, threshold):
        super(Energy, self).__init__()
        self.__threshold = threshold

    @property
    def threshold(self):
        return self.__threshold

    def compute(self, energy_1, energy_2):
        """
        Parameters
        ----------
        cell_1 : paccs.crystal.Cell
            First cell to consider.
        cell_2 : paccs.crystal.Cell
            Second cell to consider.

        Returns
        -------
        float
            Absolute value of the energy (per particle, usually) difference between the two cells.
        """
        return abs(energy_1 - energy_2)

    def __call__(self, cell_1, cell_2):
        """
        Parameters
        ----------
        cell_1 : tuple(paccs.crystal.Cell, float)
           Cell with its energy (per particle, usually), most likely generated by
           :py:func:`ResultsDatabase.cells`.
        cell_2 : tuple(paccs.crystal.Cell, float)
           Cell with its energy (per particle, usually), most likely generated by
           :py:func:`ResultsDatabase.cells`.

        Returns
        -------
        bool
            Are the two cells "the same"?
        """

        return self.compute(cell_1[1], cell_2[1]) <= self.__threshold

class PartialRDF(SimilarityMetric):
    r"""
    Compares cells by using the Frobenius norm of the difference between the matrices
    formed the radial distribution function of each component. See `Schuett et al. PRB (2014) <http://dx.doi.org/10.1103/PhysRevB.89.205118>`__.
    See :py:func:`paccs.potential._evaluate_fast` for information on the
    first two parameters. This is a mathematical metric.

    If we define the partial radial distribution function matrix as being composed
    of the radial distribution functions from unique pairs of species such that

    .. math:: {\bf g} = \begin{bmatrix} \dots g_{1,1}(r) \dots \\ \dots g_{1,2}(r) \dots \\ \vdots \\ \dots g_{1,N}(r) \dots \\ \vdots \\ \dots g_{N,N}(r) \dots \end{bmatrix},

    then :math:`{\bf g}` is an :math:`N(N+1)/2 \times {\rm n_{bins}}` matrix for N components.
    The distance between two cells is given by

    .. math:: D = \vert \vert {\bf g_1} - {\bf g_2} \vert \vert = \sqrt{ \sum_k^{\rm N(N+1)/2} \sum_s^{\rm n_{bins}} \Delta g_{k,s}^2 }.

    The `Frobenius norm <http://mathworld.wolfram.com/FrobeniusNorm.html>`_ is a special
    case of a `matrix norm <http://mathworld.wolfram.com/MatrixNorm.html>`_ and thus satisfies the triangle inequality.
    Two cells are considered the "same" if :math:`D < {\rm threshold}`.

    Notes
    -----
    This distance is **not normalized** and so it is not bounded between [0,1] as are other metrics/measures presented here.
    """

    def __init__(self, distance, bin_width, threshold):
        super(PartialRDF, self).__init__()
        self.__distance = distance
        self.__bin_width = bin_width
        self.__threshold = threshold

    def _compute_direct(self, cell):
        # Get raw pair correlation data from evaluation function
        pairs = potential._evaluate_fast(cell, None, self.__distance, self.__bin_width)[2]
        # Normalize by distance: power based on dimensions, constant factor will cancel
        pairs = pairs / (((0.5 + numpy.arange(float(pairs.shape[2]))) * self.__bin_width) \
            ** (cell.dimensions - 1))
        # Finally, normalize by atom count of the "source" type
        return pairs / numpy.repeat(numpy.array(cell.atom_counts, dtype=float), \
            pairs.shape[1] * pairs.shape[2]).reshape(pairs.shape)

    @property
    def threshold(self):
        return self.__threshold

    def compute(self, cell_1, cell_2):
        """
        Parameters
        ----------
        cell_1 : paccs.crystal.Cell
            First cell to consider.
        cell_2 : paccs.crystal.Cell
            Second cell to consider.

        Returns
        -------
        float
            Distance between cell_1 and cell_2.
        """

        # Check number of atom types
        atom_types = cell_1.atom_types
        if cell_2.atom_types != atom_types:
            raise ValueError("inconsistent number of atom types")

        # Retrieve histograms
        hist_1 = self._compute_cached(cell_1)
        hist_2 = self._compute_cached(cell_2)

        fro_norm = 0.0
        for source_type_index in range(atom_types):
            for target_type_index in range(source_type_index, atom_types):
                hist_1_vector = hist_1[source_type_index, target_type_index]
                hist_2_vector = hist_2[source_type_index, target_type_index]
                fro_norm += numpy.sum((hist_1_vector - hist_2_vector)**2)

        return numpy.sqrt(fro_norm)

    def __call__(self, cell_1, cell_2):
        """
        Parameters
        ----------
        cell_1 : tuple(paccs.crystal.Cell, float)
           Cell with its energy, most likely generated by
           :py:func:`ResultsDatabase.cells`.
        cell_2 : tuple(paccs.crystal.Cell, float)
           Cell with its energy, most likely generated by
           :py:func:`ResultsDatabase.cells`.

        Returns
        -------
        bool
            Are the two cells "the same"?
        """

        return self.compute(cell_1[0], cell_2[0]) < self.__threshold

class OVMeasure(SimilarityMetric):
    r"""
    Compares cells by computing a "soft" cosine distance measure based on the radial
    distribution functions.  This follows from `Oganov and Valle <http://aip.scitation.org/doi/abs/10.1063/1.3079326>`_ and is not a true distance metric.
    See :py:func:`paccs.potential._evaluate_fast` for information on the
    first two parameters, and :py:class:`~paccs.similarity.Histogram`
    for more details. If we define :math:`f_{i,j} = g_{i,j}(r) - 1` (Mayer-f), then this operation
    appears similar to :py:class:`paccs.similarity.CosHistogram`, where the
    latter uses :math:`g_{i,j}(r)` instead. Cells are considered the "same" if :math:`D` < threshold.

    The distance measure between two configurations is given by

    .. math:: D = \frac{1}{2} \left( 1 - \frac{\sum_{(i,j)}\sum_{k=1}^mf_{i,j}(r_k)f'_{i,j}(r_k)w_{i,j}}{\sqrt{\sum_{(i,j)}\sum_{k=1}^m{f_{i,j}(r_k)}^2w_{i,j}}\sqrt{\sum_{(i,j)}\sum_{k=1}^m{f'_{i,j}(r_k)}^2w_{i,j}}} \right),

    where the sums run over all unique (i,j) pairs and are *not* double-counted.
    However, the weighting function we use must be generalized
    a bit to accomodate the possibility of comparing cells with a different ratio
    , or total number, of particles in each.  We take

    .. math:: w_{i,j} = \frac{ \sum_{\rm cell=1}^2 N_{{\rm cell}, i} * N_{{\rm cell}, j} }{ \sum_{(i',j')} \sum_{\rm cell=1}^2 N_{{\rm cell}, i'} * N_{{\rm cell}, j'} }.

    Thus, in the special case where the stoichiometric ratio between two arbitrary
    components (A/B = X) of two cells is the same, regardless if
    they each have a different total number of components, then the relative weights
    are given by

    .. math:: w_{\rm A,A}:w_{\rm A,B}:w_{\rm B,B} = 1:(1/X):(1/X)^2.

    The equivalent matrix operations are given by

    .. math:: D = \frac{1}{2} \left( 1 - \frac{ {\rm Tr} \left( {\bf f_1} \cdot {\bf f_2}^T \cdot {\bf I} \cdot \vec{w} \right) }{ \sqrt{{\rm Tr} \left( {\bf f_1} \cdot {\bf f_1}^T \cdot {\bf I} \cdot \vec{w} \right)} \sqrt{{\rm Tr} \left( {\bf f_2} \cdot {\bf f_2}^T \cdot {\bf I} \cdot \vec{w} \right)}} \right),

    where :math:`{\bf I}` is the identity matrix and

    .. math:: {\bf f} = \begin{bmatrix} \dots f_{i,i}(r) \dots \\ \dots f_{i,j}(r) \dots \\ \dots f_{j,j}(r) \dots \end{bmatrix}, \vec{w} = \begin{bmatrix} w_{i,i} \\ w_{i,j} \\ w_{j,j} \end{bmatrix}.

    Notes that D is bounded such that :math:`0 \le D \le 1`.

    Parameters
    ----------
    threshold : float
        Magnitude of the distance metric to be considered "the same" (0 < threshold).
    """

    def __init__(self, distance, bin_width, threshold):
        super(OVMeasure, self).__init__()
        self.__distance = distance
        self.__bin_width = bin_width
        self.__threshold = threshold

    def _compute_direct(self, cell):
        # Get raw pair correlation data from evaluation function
        pairs = potential._evaluate_fast(cell, None, self.__distance, self.__bin_width)[2]
        # Normalize by distance: power based on dimensions
        if (cell.dimensions == 2):
            C = 2
        elif (cell.dimensions == 3):
            C = 4
        else:
            raise ValueError("cell dimensions must be either 2 or 3 to compute paccs.similarity.OVMeasure")
        pairs = pairs / (((0.5 + numpy.arange(float(pairs.shape[2]))) * self.__bin_width) \
            ** (cell.dimensions - 1)) / (numpy.pi * C)
        # Finally, normalize by atom count of the "source" type
        return (pairs / numpy.repeat(numpy.array(cell.atom_counts, dtype=float), \
            pairs.shape[1] * pairs.shape[2]).reshape(pairs.shape) - 1.0)

    @property
    def threshold(self):
        return self.__threshold

    def compute(self, cell_1, cell_2):
        """
        Parameters
        ----------
        cell_1 : paccs.crystal.Cell
            First cell to consider.
        cell_2 : paccs.crystal.Cell
            Second cell to consider.

        Returns
        -------
        float
            Distance between cell_1 and cell_2.
        """

        # Check number of atom types
        atom_types = cell_1.atom_types
        if cell_2.atom_types != atom_types:
            raise ValueError("inconsistent number of atom types")

        # Retrieve histograms
        hist_1 = self._compute_cached(cell_1)
        hist_2 = self._compute_cached(cell_2)

        # Choose weight based on total number of i-j pairs in the two cells
        weight_norm = 0.0
        for source_type_index in range(atom_types):
            for target_type_index in range(source_type_index, atom_types):
                weight_norm += (cell_1.atom_count(source_type_index)*cell_1.atom_count(target_type_index) + \
                    cell_2.atom_count(source_type_index)*cell_2.atom_count(target_type_index))

        # Compute the distance measure
        denominator_1 = 0.0
        denominator_2 = 0.0
        numerator = 0.0
        for source_type_index in range(atom_types):
            for target_type_index in range(source_type_index, atom_types):
                hist_1_vector = hist_1[source_type_index, target_type_index]
                hist_2_vector = hist_2[source_type_index, target_type_index]
                weight = (cell_1.atom_count(source_type_index)*cell_1.atom_count(target_type_index) + \
                    cell_2.atom_count(source_type_index)*cell_2.atom_count(target_type_index)) / weight_norm
                numerator += numpy.dot(hist_1_vector, hist_2_vector)*weight
                denominator_1 += numpy.dot(hist_1_vector, hist_1_vector)*weight
                denominator_2 += numpy.dot(hist_2_vector, hist_2_vector)*weight
        d_cos = (numerator / (numpy.sqrt(denominator_1) * numpy.sqrt(denominator_2)) if denominator_1 and denominator_2 else 0.0)

        return 0.5*(1.0 - d_cos)

    def __call__(self, cell_1, cell_2):
        """
        Parameters
        ----------
        cell_1 : tuple(paccs.crystal.Cell, float)
           Cell with its energy, most likely generated by
           :py:func:`ResultsDatabase.cells`.
        cell_2 : tuple(paccs.crystal.Cell, float)
           Cell with its energy, most likely generated by
           :py:func:`ResultsDatabase.cells`.

        Returns
        -------
        bool
            Are the two cells "the same"?
        """

        return self.compute(cell_1[0], cell_2[0]) < self.__threshold

class CosHistogram(SimilarityMetric):
    r"""
    Compares cells by computing the "soft" `cosine similarity metric <https://en.wikipedia.org/wiki/Cosine_similarity>`_ based on the radial
    distribution functions.  This is similar, but not identical to, `Oganov and Valle <http://aip.scitation.org/doi/abs/10.1063/1.3079326>`_.
    See :py:func:`paccs.potential._evaluate_fast` for information on the
    first two parameters. Cells are considered the "same" if :math:`S \ge {\rm threshold}`, where

    .. math:: S = \frac{\sum_{(i,j)}\sum_{k=1}^mg_{i,j}(r_k)g'_{i,j}(r_k)w_{i,j}}{\sqrt{\sum_{(i,j)}\sum_{k=1}^m{g_{i,j}(r_k)}^2w_{i,j}}\sqrt{\sum_{(i,j)}\sum_{k=1}^m{g'_{i,j}(r_k)}^2w_{i,j}}},

    where the sums run over all unique (i,j) pairs and are *not* double-counted.
    However, the weighting function we use must be generalized
    a bit to accomodate the possibility of comparing cells with a different ratio
    , or total number, of particles in each.  We take

    .. math:: w_{i,j} = \frac{ \sum_{\rm cell=1}^2 N_{{\rm cell}, i} * N_{{\rm cell}, j} }{ \sum_{(i',j')} \sum_{\rm cell=1}^2 N_{{\rm cell}, i'} * N_{{\rm cell}, j'} }.

    Thus,in the special case where the stoichiometric ratio between two arbitrary
    components (A/B = X) of two cells is the same, regardless if
    they each have a different total number of components, then the relative weights
    are given by

    .. math:: w_{\rm A,A}:w_{\rm A,B}:w_{\rm B,B} = 1:(1/X):(1/X)^2.

    This can be thought of in terms of matrix operations and is equivalent to

    .. math:: S = \frac{ {\rm Tr} \left( {\bf g_1} \cdot {\bf g_2}^T \cdot {\bf I} \cdot \vec{w} \right) }{ \sqrt{{\rm Tr} \left( {\bf g_1} \cdot {\bf g_1}^T \cdot {\bf I} \cdot \vec{w} \right)} \sqrt{{\rm Tr} \left( {\bf g_2} \cdot {\bf g_2}^T \cdot {\bf I} \cdot \vec{w} \right)}},

    where :math:`{\bf I}` is the identity matrix and

    .. math:: {\bf g} = \begin{bmatrix} \dots g_{i,i}(r) \dots \\ \dots g_{i,j}(r) \dots \\ \dots g_{j,j}(r) \dots \end{bmatrix}, \vec{w} = \begin{bmatrix} w_{i,i} \\ w_{i,j} \\ w_{j,j} \end{bmatrix}.

    Notes that :math:`S` is bounded such that :math:`0 \le S' \le 1`. In the case where we wish to
    compute a distance metric, this cosine similarity metric is converted to an
    `angular distance metric <https://en.wikipedia.org/wiki/Cosine_similarity>`_, :math:`D`, which is a formal distance metric, while :math:`1 - S` is not.

    .. math:: D = \frac{{\rm cos}^{-1}(S)}{\pi / 2}

    In principle, this can be used to define a new similarity metric,

    .. math:: S' = 1 - D,

    which is known as the "angular similarity" such that :math:`0 \le S' \le 1`.
    Note that this also implies that :math:`0 \le D \le 1`.

    Parameters
    ----------
    threshold : float
        Magnitude of the metric to be considered "the same". If computing similarity then :math:`S \ge {\rm threshold}` is tested; if computing the distance, then :math:`D < {\rm threshold}` is tested. In both cases :math:`0 \le {\rm threshold} \le 1`.
    compute : str
        Tells the routine to compute either the "similarity" (default) or the angular "distance" metric.
    """

    def __init__(self, distance, bin_width, threshold, compute='similarity'):
        super(CosHistogram, self).__init__()
        self.__distance = distance
        self.__bin_width = bin_width
        self.__threshold = threshold
        if (compute not in ['similarity', 'distance']): raise ValueError('unknown compute type: {}'.format(compute))
        self.__compute = compute

    def _compute_direct(self, cell):
        # Get raw pair correlation data from evaluation function
        pairs = potential._evaluate_fast(cell, None, self.__distance, self.__bin_width)[2]
        # Normalize by distance: power based on dimensions, constant factor will cancel
        pairs = pairs / (((0.5 + numpy.arange(float(pairs.shape[2]))) * self.__bin_width) \
            ** (cell.dimensions - 1))
        # Finally, normalize by atom count of the "source" type
        return pairs / numpy.repeat(numpy.array(cell.atom_counts, dtype=float), \
            pairs.shape[1] * pairs.shape[2]).reshape(pairs.shape)

    @property
    def threshold(self):
        return self.__threshold

    def compute(self, cell_1, cell_2):
        """
        Parameters
        ----------
        cell_1 : paccs.crystal.Cell
            First cell to consider.
        cell_2 : paccs.crystal.Cell
            Second cell to consider.

        Returns
        -------
        float
            Either similarity or angular distance between cell_1 and cell_2.
        """

        # Check number of atom types
        atom_types = cell_1.atom_types
        if (cell_2.atom_types != atom_types):
            raise ValueError("inconsistent number of atom types")

        # Retrieve histograms
        hist_1 = self._compute_cached(cell_1)
        hist_2 = self._compute_cached(cell_2)

        # Choose weight based on total number of i-j pairs in the two cells
        weight_norm = 0.0
        for source_type_index in range(atom_types):
            for target_type_index in range(source_type_index, atom_types):
                weight_norm += (cell_1.atom_count(source_type_index)*cell_1.atom_count(target_type_index) + \
                    cell_2.atom_count(source_type_index)*cell_2.atom_count(target_type_index))

        # Compute the similarity or distance metric
        denominator_1 = 0.0
        denominator_2 = 0.0
        numerator = 0.0
        for source_type_index in range(atom_types):
            for target_type_index in range(source_type_index, atom_types):
                hist_1_vector = hist_1[source_type_index, target_type_index]
                hist_2_vector = hist_2[source_type_index, target_type_index]
                weight = (cell_1.atom_count(source_type_index)*cell_1.atom_count(target_type_index) + \
                    cell_2.atom_count(source_type_index)*cell_2.atom_count(target_type_index)) / weight_norm
                numerator += numpy.dot(hist_1_vector, hist_2_vector)*weight
                denominator_1 += numpy.dot(hist_1_vector, hist_1_vector)*weight
                denominator_2 += numpy.dot(hist_2_vector, hist_2_vector)*weight
        s_cos = (numerator / (numpy.sqrt(denominator_1) * numpy.sqrt(denominator_2)) if denominator_1 and denominator_2 else 0.0)

        if (self.__compute == 'similarity'):
            return s_cos
        elif (self.__compute == 'distance'):
            return 2.0*numpy.arccos(s_cos)/numpy.pi
        else:
            raise ValueError('unknown compute type: {}'.format(self.__compute))

    def __call__(self, cell_1, cell_2):
        """
        Parameters
        ----------
        cell_1 : tuple(paccs.crystal.Cell, float)
           Cell with its energy, most likely generated by
           :py:func:`ResultsDatabase.cells`.
        cell_2 : tuple(paccs.crystal.Cell, float)
           Cell with its energy, most likely generated by
           :py:func:`ResultsDatabase.cells`.

        Returns
        -------
        bool
            Are the two cells "the same"?
        """

        if (self.__compute == 'similarity'):
            return self.compute(cell_1[0], cell_2[0]) >= self.__threshold
        elif (self.__compute == 'distance'):
            return self.compute(cell_1[0], cell_2[0]) < self.__threshold
        else:
            raise ValueError('unknown compute type: {}'.format(self.__compute))

class Histogram(SimilarityMetric):
    r"""
    Compares cells by computing the `cosine similarity metric <https://en.wikipedia.org/wiki/Cosine_similarity>`_
    based on radial distribution functions to produce a fingerprint vector.  See
    :py:func:`~paccs.potential._evaluate_fast` for information
    on the first two parameters.  This treats each i-j pair type more
    individually than :py:class:`CosHistogram` and :py:class:`paccs.similarity.OVMeasure`
    by allowing the norm to be specified, treating each i-j interaction as a
    separate component of the fingerprint vector. The fingerprint vector is composed of the cosine similarities
    between the radial distribution functions for :math:`N` particle types, for all unique pairs,
    :math:`\vec{S} = \langle S_{1,1}, S_{1,2}, \dots, S_{1,N}, S_{2,2}, S_{2,3} \dots, S_{N,N} \rangle`

    .. math:: S_{i,j}({\rm cell,cell'})= \frac{ \sum_{k=1}^m g_{i,j}(r_k)g'_{i,j}(r_k) }{ \sqrt{ \sum_{k=1}^m {g_{i,j}(r_k)}^2 } \sqrt{ \sum_{k=1}^m {g'_{i,j}(r_k)}^2 } }

    The `vector norm <http://mathworld.wolfram.com/VectorNorm.html>`_ (as specified) of :math:`\vec{S}` is then returned as the value of the measure.
    Note that :math:`S_{i,j}` is bounded by [0,1]. To also bound the norm of this vector by [0,1],
    the norm functions provided here also normalize based on the length of :math:`\vec{S}` (equal to :math:`N(N+1)/2`).
    See :py:class:`paccs.similarity.Minkowski`. Two cells are considered the "same" if :math:`|S|` >= threshold.

    **Depending on the norm chosen, this is not always guaranteed to be a metric, and should be generally considered a measure instead.**

    Parameters
    ----------
    threshold : float
        Magnitude of the similarity metric to be considered "the same" (:math:`0 \le {\rm threshold} \le 1`).
    norm : callable
        A norm used to reduce multiple similarity metric values into one, resulting in a measure (sometimes another metric).
        Can be a built-in (created by :py:func:`Minkowski`, :py:func:`Manhattan`,
        :py:func:`Euclidean`, or :py:func:`Minimum`), or can be any arbitrary
        callable accepting a 1-D :py:class:`numpy.ndarray` and returning a single
        value.  All input values will be in the range :math:`[0, 1]`, and the output
        value should be in this range as well.  The default norm is an instance of
        :py:func:`Manhattan`, which computes the algebraic mean.
    radii : dict(tuple(str,str), float)
        Dictionary of radii for each species, if it is desired to make the comparison between cells when 
        when they are scaled to "contact" instead.  This scaling only occurs for a cell if its scale_factor
        is less than the scale_limit; scaled and unscaled comparisons are possible. If not specified, no 
        scaling will ever be used. The original cell is not modified by this operation.
    scale_limit : float
        Maximum scale_factor to allow comparison at "contact" instead of the exact coordinates of the cells
        provided.  If a cell's scale_factor is larger than this, the original cell is used in the comparison
        instead of a the rescaled version.
    """

    def __init__(self, distance, bin_width, threshold, norm=Manhattan(), radii=None, scale_limit=numpy.inf):
        super(Histogram, self).__init__()
        self.__distance = distance
        self.__bin_width = bin_width
        self.__threshold = threshold
        self.__norm = norm
        self.__radii = copy.copy(radii)
        self.__scale_limit = scale_limit
        self.__scale_cache = {}

    def _compute_direct(self, cell):
        if (self.__radii is None):
            use_cell = cell
        else:
            if (cell not in self.__scale_cache):
                names_in_radii = set(self.__radii.keys())
                names_in_cell = set(cell.names)
                if not (names_in_radii == names_in_cell):
                    raise Exception('names in cell ({}) do not match the specified radii ({})'.format(names_in_cell, names_in_radii))
                radii = tuple([self.__radii[x] for x in sorted(names_in_radii)])
                self.__scale_cache[cell] = cell.scale_factor(radii)
            if (self.__scale_cache[cell] < self.__scale_limit):
                use_cell = crystal.CellTools.scale(cell, cell.vectors/self.__scale_cache[cell])
            else:
                use_cell = cell

        # Get raw pair correlation data from evaluation function
        pairs = potential._evaluate_fast(use_cell, None, self.__distance, self.__bin_width)[2]
        # Normalize by distance: power based on dimensions, constant factor will cancel
        pairs = pairs / (((0.5 + numpy.arange(float(pairs.shape[2]))) * self.__bin_width) \
            ** (use_cell.dimensions - 1))
        # Finally, normalize by atom count of the "source" type
        return pairs / numpy.repeat(numpy.array(use_cell.atom_counts, dtype=float), \
            pairs.shape[1] * pairs.shape[2]).reshape(pairs.shape)

    @property
    def threshold(self):
        return self.__threshold

    def compute(self, cell_1, cell_2):
        """
        Parameters
        ----------
        cell_1 : paccs.crystal.Cell
            First cell to consider.
        cell_2 : paccs.crystal.Cell
            Second cell to consider.

        Returns
        -------
        float
            Similarity between cell_1 and cell_2.
        """

        # Check number of atom types
        atom_types = cell_1.atom_types
        if cell_2.atom_types != atom_types:
            raise ValueError("inconsistent number of atom types")

        # Retrieve histograms
        hist_1 = self._compute_cached(cell_1)
        hist_2 = self._compute_cached(cell_2)

        # Compute the similarity metric
        similarity_metric = []
        for source_type_index in range(atom_types):
            for target_type_index in range(source_type_index, atom_types):
                hist_1_vector = hist_1[source_type_index, target_type_index]
                hist_2_vector = hist_2[source_type_index, target_type_index]
                square_denominator = numpy.dot(hist_1_vector, hist_1_vector) * numpy.dot(hist_2_vector, hist_2_vector)
                similarity_metric.append(numpy.dot(hist_1_vector, hist_2_vector) / (numpy.sqrt(square_denominator)) if square_denominator else 0.0)

        return self.__norm(numpy.array(similarity_metric))

    def __call__(self, cell_1, cell_2):
        """
        Parameters
        ----------
        cell_1 : tuple(paccs.crystal.Cell, float)
           Cell with its energy, most likely generated by
           :py:func:`ResultsDatabase.cells`.
        cell_2 : tuple(paccs.crystal.Cell, float)
           Cell with its energy, most likely generated by
           :py:func:`ResultsDatabase.cells`.

        Returns
        -------
        bool
            Are the two cells "the same"?
        """

        return self.compute(cell_1[0], cell_2[0]) >= self.__threshold
