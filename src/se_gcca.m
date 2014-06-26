function [G, S_tilde, sort_idx] = se_gcca(S, B, r, b, svd_reg_seq)
% S is a cell with singular values
% B contains associated singular vectors
% r is the number of gcca components we want
% b is the step size from 1 to N
% svd_reg_seq is the regularization to apply to each component.
J = length(S);
N = size(B{1}, 1);
assert(length(svd_reg_seq)==J && length(B)==J); 
assert(all(arrayfun(@(i) size(B{i}, 1), 1:J)==N));
assert(length(S{1})==size(B{1}, 2));
ovguard = @(l, b) min(l+b-1, N);
for i=1:J
    if size(S{i}, 1)~=1
        S{i}=S{i}';
        fprintf(1, 'S{%d} was a column we made it a row\n', i);
    end
end
U_tilde=zeros(N, r);
S_tilde=zeros(1, r);


% We rearrange the rows and columns that we process according to
% their norm so that the error in the SVD remains low. See
% test_incrementalSVD.m for more information

tic; 
for l=1:b:N
    column_norm(l:ovguard(l, b))=sum(...
        get_columns(S, B, l:ovguard(l, b), svd_reg_seq).^2, ...
        1);
end
[~, sort_idx]=sort(column_norm, 'descend');
assert(size(sort_idx,1)==1);
fprintf(1, 'get_column over entire matrix takes %f seconds\n', toc);

tic;
for l=1:b:N
    if mod(l, 1000)==0
        fprintf(2, 'Will process %d th column out of %d\n', l, N);
    end
    Cl = get_columns(S, B, sort_idx(l:ovguard(l, b)), svd_reg_seq);
    Cl=Cl(sort_idx,:); % Also shuffle the rows so that C remains a
                           % kernel matrix.
    [U_tilde_new, S_tilde_new, St_discarded, Ut_discarded]= ...
        incrementalSVD(Cl, U_tilde, S_tilde, r);
        
    S_tilde=S_tilde_new;
    U_tilde=U_tilde_new;
    % Orthogonalize using modified gram schmidt if eigen 
    % directions become non orthogonal
    if abs(U_tilde(:,1)'*U_tilde(:, r)) > 10*eps('double')
        warning('U_tilde has become non-orthogonal'); %#ok<*WNTAG>
        U_tilde=m_gsm(U_tilde);
    end
end
G = U_tilde';
fprintf(1, 'The core CCA takes %f seconds\n', toc);
end

function C = get_columns(S, B, idx, svd_reg_seq)
% This function calculates columns within idx by using S and B and the
% svd_regularization_sequence (which puts a separater regularization
% sequence for each language pair.
a_by_apb=@(a,b) a./(a+b);
C = zeros(size(B{1}, 1), length(idx));
for j=1:length(S)
    sj_prime=a_by_apb(S{j}.^2, svd_reg_seq(j));
    C = C +B{j}*transpose(repmat(sj_prime, length(idx), 1).*B{j}(idx, :));
end
end
