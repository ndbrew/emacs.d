;; Make all commands of the “package” module present.
(require 'package)

;; Internet repositories for new packages.
(setq package-archives '(("gnu"    . "http://elpa.gnu.org/packages/")
                         ("nongnu" . "https://elpa.nongnu.org/nongnu/")
                         ("melpa"  . "http://melpa.org/packages/")))

;; Update local list of available packages:
;; Get descriptions of all configured ELPA packages,
;; and make them available for download.
;; (package-refresh-contents)

(unless (package-installed-p 'use-package)
  (package-install 'use-package))
(require 'use-package)

(setq use-package-always-ensure t)

(use-package auto-package-update
  :defer 10
  :config
  ;; Delete residual old versions
  (setq auto-package-update-delete-old-versions t)
  ;; Do not bother me when updates have taken place.
  (setq auto-package-update-hide-results t)
  ;; Update installed packages at startup if there is an update pending.
  (auto-package-update-maybe))

;; Making it easier to discover Emacs key presses.
(use-package which-key
  :diminish
  :defer 5
  :config (which-key-mode)
          (which-key-setup-side-window-bottom)
          (setq which-key-idle-delay 0.05))

(use-package diminish
  :defer 5
  :config ;; Let's hide some markers.
    (diminish  'org-indent-mode))

;; Efficient version control.
;;
;; Bottom of Emacs will show what branch you're on
;; and whether the local file is modified or not.
(use-package magit
  :config (global-set-key (kbd "C-x g") 'magit-status))

;; Main use: Org produced htmls are coloured.
;; Can be used to export a file into a coloured html.
(use-package htmlize :defer t)

;; “The long lost Emacs string manipulation library”.
(use-package s)

;; Library for working with system files;
;; e.g., f-delete, f-mkdir, f-move, f-exists?, f-hidden?
(use-package f)

(defun my/git-commit-reminder ()
  (insert "\n\n# The commit subject line ought to finish the phrase:
# “If applied, this commit will ⟪your subject line here⟫.” ")
  (beginning-of-buffer))

(add-hook 'git-commit-setup-hook 'my/git-commit-reminder)

(defun my/make-init-el ()
  "Tangle an el and a github README from my init.org."
  ;;(interactive "P")
  ;;(when current-prefix-arg
    (let* ((time      (current-time))
	   (_date     (format-time-string "_%Y-%m-%d"))
	   (.emacs    "~/.emacs")
	   (.emacs.el "~/.emacs.el"))
      ;; Make README.org
      ;;(save-excursion
      ;;  (org-babel-goto-named-src-block "make-readme") ;; See next subsubsection.
      ;;  (org-babel-execute-src-block))

      ;; remove any other initialisation file candidates
      ;;(ignore-errors


      ;;  (f-move .emacs    (concat .emacs _date))
      ;;  (f-move .emacs.el (concat .emacs.el _date)))

      ;; Make init.el
      (org-babel-tangle)
      ;; (byte-compile-file "init.el")
      (load-file "init.el")

      ;; Acknowledgement
      (message "Tangled, compiled, and loaded init.el … %.06f seconds"
	       (float-time (time-since time)))))
    ;;)

(add-hook 'after-save-hook 'my/make-init-el nil 'local-to-this-file-please)

;; Restricts agenda to project tasks
(defun bh/narrow-to-project ()
  (interactive)
  (if (equal major-mode 'org-agenda-mode)
      (progn
        (org-with-point-at (bh/get-pom-from-agenda-restriction-or-point)
          (bh/narrow-to-org-project)
          (save-excursion
            (bh/find-project-task)
            (org-agenda-set-restriction-lock)))
        (org-agenda-redo)
        (beginning-of-buffer))
    (bh/narrow-to-org-project)
    (save-restriction
      (org-agenda-set-restriction-lock))))

(defun bh/skip-non-stuck-projects ()
  "Skip trees that are not stuck projects"
  ;;(bh/list-sublevels-for-projects-indented)
  (save-restriction
    (widen)
    (let ((next-headline (save-excursion (or (outline-next-heading) (point-max)))))
      (if (bh/is-project-p)
          (let* ((subtree-end (save-excursion (org-end-of-subtree t)))
                 (has-next ))
            (save-excursion
              (forward-line 1)
              (while (and (not has-next) (< (point) subtree-end) (re-search-forward "^\\*+ NEXT " subtree-end t))
                (unless (member "WAITING" (org-get-tags-at))
                  (setq has-next t))))
            (if has-next
                next-headline
              nil)) ; a stuck project, has subtasks but no next task
        next-headline))))

(defun bh/skip-non-projects ()
  "Skip trees that are not projects"
  ;;(bh/list-sublevels-for-projects-indented)
  (if (save-excursion (bh/skip-non-stuck-projects))
      (save-restriction
        (widen)
        (let ((subtree-end (save-excursion (org-end-of-subtree t))))
          (cond
           ((bh/is-project-p)
            nil)
           ((and (bh/is-project-subtree-p) (not (bh/is-task-p)))
            nil)
           (t
            subtree-end))))
    (save-excursion (org-end-of-subtree t))))

(defun bh/skip-projects-and-habits-and-single-tasks ()
  "Skip trees that are projects, tasks that are habits, single non-project tasks"
  (save-restriction
    (widen)
    (let ((next-headline (save-excursion (or (outline-next-heading) (point-max)))))
      (cond
       ((org-is-habit-p)
        next-headline)
       ((and bh/hide-scheduled-and-waiting-next-tasks
             (member "WAITING" (org-get-tags-at)))
        next-headline)
       ((bh/is-project-p)
        next-headline)
       ((and (bh/is-task-p) (not (bh/is-project-subtree-p)))
        next-headline)
       (t
        nil)))))

(defun bh/skip-non-project-tasks ()
  "Show project tasks.
Skip project and sub-project tasks, habits, and loose non-project tasks."
  (save-restriction
    (widen)
    (let* ((subtree-end (save-excursion (org-end-of-subtree t)))
           (next-headline (save-excursion (or (outline-next-heading) (point-max)))))
      (cond
       ((bh/is-project-p)
        next-headline)
       ((org-is-habit-p)
        subtree-end)
       ((and (bh/is-project-subtree-p)
             (member (org-get-todo-state) (list "NEXT")))
        subtree-end)
       ((not (bh/is-project-subtree-p))
        subtree-end)
       (t
        nil)))))

(defun bh/skip-project-tasks ()
  "Show non-project tasks.
Skip project and sub-project tasks, habits, and project related tasks."
  (save-restriction
    (widen)
    (let* ((subtree-end (save-excursion (org-end-of-subtree t))))
      (cond
       ((bh/is-project-p)
        subtree-end)
       ((org-is-habit-p)
        subtree-end)
       ((bh/is-project-subtree-p)
        subtree-end)
       (t
        nil)))))

(defun bh/skip-non-archivable-tasks ()
  "Skip trees that are not available for archiving"
  (save-restriction
    (widen)
    ;; Consider only tasks with done todo headings as archivable candidates
    (let ((next-headline (save-excursion (or (outline-next-heading) (point-max))))
          (subtree-end (save-excursion (org-end-of-subtree t))))
      (if (member (org-get-todo-state) org-todo-keywords-1)
          (if (member (org-get-todo-state) org-done-keywords)
              (let* ((daynr (string-to-int (format-time-string "%d" (current-time))))
                     (a-month-ago (* 60 60 24 (+ daynr 1)))
                     (last-month (format-time-string "%Y-%m-" (time-subtract (current-time) (seconds-to-time a-month-ago))))
                     (this-month (format-time-string "%Y-%m-" (current-time)))
                     (subtree-is-current (save-excursion
                                           (forward-line 1)
                                           (and (< (point) subtree-end)
                                                (re-search-forward (concat last-month "\\|" this-month) subtree-end t)))))
                (if subtree-is-current
                    subtree-end ; Has a date in this month or last month, skip it
                  nil))  ; available to archive
            (or subtree-end (point-max)))
        next-headline))))

(defun bh/is-project-p ()
  "Any task with a todo keyword subtask"
  (save-restriction
    (widen)
    (let ((has-subtask)
          (subtree-end (save-excursion (org-end-of-subtree t)))
          (is-a-task (member (nth 2 (org-heading-components)) org-todo-keywords-1)))
      (save-excursion
        (forward-line 1)
        (while (and (not has-subtask)
                    (< (point) subtree-end)
                    (re-search-forward "^\*+ " subtree-end t))
          (when (member (org-get-todo-state) org-todo-keywords-1)
            (setq has-subtask t))))
      (and is-a-task has-subtask))))

(defun bh/is-project-subtree-p ()
  "Any task with a todo keyword that is in a project subtree.
Callers of this function already widen the buffer view."
  (let ((task (save-excursion (org-back-to-heading 'invisible-ok)
                              (point))))
    (save-excursion
      (bh/find-project-task)
      (if (equal (point) task)
          nil
        t))))

(defun bh/is-task-p ()
  "Any task with a todo keyword and no subtask"
  (save-restriction
    (widen)
    (let ((has-subtask)
          (subtree-end (save-excursion (org-end-of-subtree t)))
          (is-a-task (member (nth 2 (org-heading-components)) org-todo-keywords-1)))
      (save-excursion
        (forward-line 1)
        (while (and (not has-subtask)
                    (< (point) subtree-end)
                    (re-search-forward "^\*+ " subtree-end t))
          (when (member (org-get-todo-state) org-todo-keywords-1)
            (setq has-subtask t))))
      (and is-a-task (not has-subtask))
      )
    )
  )

(defun bh/find-project-task ()
  "Move point to the parent (project) task if any"
  (save-restriction
    (widen)
    (let ((parent-task (save-excursion (org-back-to-heading 'invisible-ok) (point))))
      (while (org-up-heading-safe)
        (when (member (nth 2 (org-heading-components)) org-todo-keywords-1)
          (setq parent-task (point))))
      (goto-char parent-task)
      parent-task)))

(defun bh/get-pom-from-agenda-restriction-or-point ()
  "Get marker position"
  (or (and (marker-position org-agenda-restrict-begin) org-agenda-restrict-begin)
      (org-get-at-bol 'org-hd-marker)
      (and (equal major-mode 'org-mode) (point))
      org-clock-marker))

(defun bh/narrow-to-org-project ()
  (widen)
  (save-excursion
    (bh/find-project-task)
    (bh/narrow-to-org-subtree)))

(defun bh/narrow-to-org-subtree ()
  (widen)
  (org-narrow-to-subtree)
  (save-restriction
    (org-agenda-set-restriction-lock)))

(defun bh/widen ()
  (interactive)
  (if (equal major-mode 'org-agenda-mode)
      (progn
        (org-agenda-remove-restriction-lock)
        (when org-agenda-sticky
          (org-agenda-redo)))
    (widen)))

(defun bh/set-agenda-restriction-lock (arg)
  "Set restriction lock to current task subtree or file if prefix is specified"
  (interactive "p")
  (let* ((pom (bh/get-pom-from-agenda-restriction-or-point))
         (tags (org-with-point-at pom (org-get-tags-at))))
    (let ((restriction-type (if (equal arg 4) 'file 'subtree)))
      (save-restriction
        (cond
         ((and (equal major-mode 'org-agenda-mode) pom)
          (org-with-point-at pom
            (org-agenda-set-restriction-lock restriction-type))
          (org-agenda-redo))
         ((and (equal major-mode 'org-mode) (org-before-first-heading-p))
          (org-agenda-set-restriction-lock 'file))
         (pom
          (org-with-point-at pom
            (org-agenda-set-restriction-lock restriction-type))))))))

(defun bh/restrict-to-file-or-follow (arg)
  "Set agenda restriction to 'file or with argument invoke follow mode.
I don't use follow mode very often but I restrict to file all the time
so change the default 'F' binding in the agenda to allow both"
  (interactive "p")
  (if (equal arg 4)
      (org-agenda-follow-mode)
    (widen)
    (bh/set-agenda-restriction-lock 4)
    (org-agenda-redo)
    (beginning-of-buffer)))

(defun bh/mark-next-parent-tasks-todo ()
"Visit each parent task and change NEXT states to TODO"
(let ((mystate (or (and (fboundp 'org-state)
                          state)
                     (nth 2 (org-heading-components)))))
    (when mystate
      (save-excursion
        (while (org-up-heading-safe)
          (when (member (nth 2 (org-heading-components)) (list "NEXT"))
            (org-todo "TODO")))))))

(defun bh/is-subproject-p ()
  "Any task which is a subtask of another project"
  (let ((is-subproject)
        (is-a-task (member (nth 2 (org-heading-components)) org-todo-keywords-1)))
    (save-excursion
      (while (and (not is-subproject) (org-up-heading-safe))
        (when (member (nth 2 (org-heading-components)) org-todo-keywords-1)
          (setq is-subproject t))))
    (and is-a-task is-subproject)))

(defun bh/list-sublevels-for-projects-indented ()
  "Set org-tags-match-list-sublevels so when restricted to a subtree we list all subtasks.
  This is normally used by skipping functions where this variable is already local to the agenda."
  (if (marker-buffer org-agenda-restrict-begin)
      (setq org-tags-match-list-sublevels 'indented)
    (setq org-tags-match-list-sublevels nil))
  nil)

(defun bh/list-sublevels-for-projects ()
  "Set org-tags-match-list-sublevels so when restricted to a subtree we list all subtasks.
  This is normally used by skipping functions where this variable is already local to the agenda."
  (if (marker-buffer org-agenda-restrict-begin)
      (setq org-tags-match-list-sublevels t)
    (setq org-tags-match-list-sublevels nil))
  nil)

(defun bh/toggle-next-task-display ()
  (interactive)
  (setq bh/hide-scheduled-and-waiting-next-tasks (not bh/hide-scheduled-and-waiting-next-tasks))
  (when  (equal major-mode 'org-agenda-mode)
    (org-agenda-redo))
  (message "%s WAITING and SCHEDULED NEXT Tasks" (if bh/hide-scheduled-and-waiting-next-tasks "Hide" "Show")))

(defun bh/skip-stuck-projects ()
  "Skip trees that are not stuck projects"
  (save-restriction
    (widen)
    (let ((next-headline (save-excursion (or (outline-next-heading) (point-max)))))
      (if (bh/is-project-p)
          (let* ((subtree-end (save-excursion (org-end-of-subtree t)))
                 (has-next ))
            (save-excursion
              (forward-line 1)
              (while (and (not has-next) (< (point) subtree-end) (re-search-forward "^\\*+ NEXT " subtree-end t))
                (unless (member "WAITING" (org-get-tags-at))
                  (setq has-next t))))
            (if has-next
                nil
              next-headline)) ; a stuck project, has subtasks but no next task
        nil))))


(defun bh/skip-project-trees-and-habits ()
  "Skip trees that are projects"
  (save-restriction
    (widen)
    (let ((subtree-end (save-excursion (org-end-of-subtree t))))
      (cond
       ((bh/is-project-p)
        subtree-end)
      ((org-is-habit-p)
        subtree-end)
       (t
        nil)))))

(defun bh/skip-project-tasks-maybe ()
  "Show tasks related to the current restriction.
When restricted to a project, skip project and sub project tasks, habits, NEXT tasks, and loose tasks.
When not restricted, skip project and sub-project tasks, habits, and project related tasks."
  (save-restriction
    (widen)
    (let* ((subtree-end (save-excursion (org-end-of-subtree t)))
           (next-headline (save-excursion (or (outline-next-heading) (point-max))))
           (limit-to-project (marker-buffer org-agenda-restrict-begin)))
      (cond
       ((bh/is-project-p)
        next-headline)
       ((org-is-habit-p)
        subtree-end)
       ((and (not limit-to-project)
             (bh/is-project-subtree-p))
        subtree-end)
       ((and limit-to-project
             (bh/is-project-subtree-p)
             (member (org-get-todo-state) (list "NEXT")))
        subtree-end)
       (t
        nil)))))

(defun bh/skip-projects-and-habits ()
  "Skip trees that are projects and tasks that are habits"
  (save-restriction
    (widen)
    (let ((subtree-end (save-excursion (org-end-of-subtree t))))
      (cond
       ((bh/is-project-p)
        subtree-end)
       ((org-is-habit-p)
        subtree-end)
       (t
        nil)))))

(defun bh/skip-non-subprojects ()
  "Skip trees that are not projects"
  (let ((next-headline (save-excursion (outline-next-heading))))
    (if (bh/is-subproject-p)
        nil
      next-headline)))

; Erase all reminders and rebuilt reminders for today from the agenda
(defun bh/org-agenda-to-appt ()
  (interactive)
  (setq appt-time-msg-list nil)
  (org-agenda-to-appt))

(defun bh/org-todo (arg)
  (interactive "p")
  (if (equal arg 4)
      (save-restriction
        (bh/narrow-to-org-subtree)
        (org-show-todo-tree nil))
    (bh/narrow-to-org-subtree)
    (org-show-todo-tree nil)))

(defun bh/narrow-to-subtree ()
  (interactive)
  (if (equal major-mode 'org-agenda-mode)
      (progn
        (org-with-point-at (org-get-at-bol 'org-hd-marker)
          (bh/narrow-to-org-subtree))
        (when org-agenda-sticky
          (org-agenda-redo)))
    (bh/narrow-to-org-subtree)))

(defun bh/narrow-up-one-org-level ()
  (widen)
  (save-excursion
    (outline-up-heading 1 'invisible-ok)
    (bh/narrow-to-org-subtree)))


(defun bh/narrow-up-one-level ()
  (interactive)
  (if (equal major-mode 'org-agenda-mode)
      (progn
        (org-with-point-at (bh/get-pom-from-agenda-restriction-or-point)
          (bh/narrow-up-one-org-level))
        (org-agenda-redo))
    (bh/narrow-up-one-org-level)))

(defun bh/view-next-project ()
  (interactive)
  (let (num-project-left current-project)
    (unless (marker-position org-agenda-restrict-begin)
      (goto-char (point-min))
      ; Clear all of the existing markers on the list
      (while bh/project-list
        (set-marker (pop bh/project-list) nil))
      (re-search-forward "Tasks to Refile")
      (forward-visible-line 1))

    ; Build a new project marker list
    (unless bh/project-list
      (while (< (point) (point-max))
        (while (and (< (point) (point-max))
                    (or (not (org-get-at-bol 'org-hd-marker))
                        (org-with-point-at (org-get-at-bol 'org-hd-marker)
                          (or (not (bh/is-project-p))
                              (bh/is-project-subtree-p)))))
          (forward-visible-line 1))
        (when (< (point) (point-max))
          (add-to-list 'bh/project-list (copy-marker (org-get-at-bol 'org-hd-marker)) 'append))
        (forward-visible-line 1)))

    ; Pop off the first marker on the list and display
    (setq current-project (pop bh/project-list))
    (when current-project
      (org-with-point-at current-project
        (setq bh/hide-scheduled-and-waiting-next-tasks nil)
        (bh/narrow-to-project))
      ; Remove the marker
      (setq current-project nil)
      (org-agenda-redo)
      (beginning-of-buffer)
      (setq num-projects-left (length bh/project-list))
      (if (> num-projects-left 0)
          (message "%s projects left to view" num-projects-left)
        (beginning-of-buffer)
        (setq bh/hide-scheduled-and-waiting-next-tasks t)
        (error "All projects viewed.")))))
(defun bh/agenda-sort (a b)
  "Sorting strategy for agenda items.
Late deadlines first, then scheduled, then non-late deadlines"
  (let (result num-a num-b)
    (cond
     ; time specific items are already sorted first by org-agenda-sorting-strategy

     ; non-deadline and non-scheduled items next
     ((bh/agenda-sort-test 'bh/is-not-scheduled-or-deadline a b))

     ; deadlines for today next
     ((bh/agenda-sort-test 'bh/is-due-deadline a b))

     ; late deadlines next
     ((bh/agenda-sort-test-num 'bh/is-late-deadline '> a b))

     ; scheduled items for today next
     ((bh/agenda-sort-test 'bh/is-scheduled-today a b))

     ; late scheduled items next
     ((bh/agenda-sort-test-num 'bh/is-scheduled-late '> a b))

     ; pending deadlines last
     ((bh/agenda-sort-test-num 'bh/is-pending-deadline '< a b))

     ; finally default to unsorted
     (t (setq result nil)))
    result))

(defmacro bh/agenda-sort-test (fn a b)
  "Test for agenda sort"
  `(cond
    ; if both match leave them unsorted
    ((and (apply ,fn (list ,a))
          (apply ,fn (list ,b)))
     (setq result nil))
    ; if a matches put a first
    ((apply ,fn (list ,a))
     (setq result -1))
    ; otherwise if b matches put b first
    ((apply ,fn (list ,b))
     (setq result 1))
    ; if none match leave them unsorted
    (t nil)))

(defmacro bh/agenda-sort-test-num (fn compfn a b)
  `(cond
    ((apply ,fn (list ,a))
     (setq num-a (string-to-number (match-string 1 ,a)))
     (if (apply ,fn (list ,b))
         (progn
           (setq num-b (string-to-number (match-string 1 ,b)))
           (setq result (if (apply ,compfn (list num-a num-b))
                            -1
                          1)))
       (setq result -1)))
    ((apply ,fn (list ,b))
     (setq result 1))
    (t nil)))

(defun bh/is-not-scheduled-or-deadline (date-str)
  (and (not (bh/is-deadline date-str))
       (not (bh/is-scheduled date-str))))

(defun bh/is-due-deadline (date-str)
  (string-match "Deadline:" date-str))

(defun bh/is-late-deadline (date-str)
  (string-match "\\([0-9]*\\) d\. ago:" date-str))

(defun bh/is-pending-deadline (date-str)
  (string-match "In \\([^-]*\\)d\.:" date-str))

(defun bh/is-deadline (date-str)
  (or (bh/is-due-deadline date-str)
      (bh/is-late-deadline date-str)
      (bh/is-pending-deadline date-str)))

(defun bh/is-scheduled (date-str)
  (or (bh/is-scheduled-today date-str)
      (bh/is-scheduled-late date-str)))

(defun bh/is-scheduled-today (date-str)
  (string-match "Scheduled:" date-str))

(defun bh/is-scheduled-late (date-str)
  (string-match "Sched\.\\(.*\\)x:" date-str))
(defun bh/show-org-agenda ()
  (interactive)
  (if org-agenda-sticky
      (switch-to-buffer "*Org Agenda( )*")
    (switch-to-buffer "*Org Agenda*"))
  (delete-other-windows))
(defun bh/toggle-insert-inactive-timestamp ()
  (interactive)
  (setq bh/insert-inactive-timestamp (not bh/insert-inactive-timestamp))
  (message "Heading timestamps are %s" (if bh/insert-inactive-timestamp "ON" "OFF")))

(defun bh/insert-inactive-timestamp ()
  (interactive)
  (org-insert-time-stamp nil t t nil nil nil))

(defun bh/insert-heading-inactive-timestamp ()
  (save-excursion
    (when bh/insert-inactive-timestamp
      (org-return)
      (org-cycle)
      (bh/insert-inactive-timestamp))))

(defun bh/prepare-meeting-notes ()
"Prepare meeting notes for email
   Take selected region and convert tabs to spaces, mark TODOs with leading >>>, and copy to kill ring for pasting"
  (interactive)
  (let (prefix)
    (save-excursion
      (save-restriction
        (narrow-to-region (region-beginning) (region-end))
        (untabify (point-min) (point-max))
        (goto-char (point-min))
        (while (re-search-forward "^\\( *-\\\) \\(TODO\\|DONE\\): " (point-max) t)
          (replace-match (concat (make-string (length (match-string 1)) ?>) " " (match-string 2) ": ")))
        (goto-char (point-min))
        (kill-ring-save (point-min) (point-max))))))
(defun bh/verify-refile-target ()
  "Exclude todo keywords with a done state from refile targets"
  (not (member (nth 2 (org-heading-components)) org-done-keywords)))
(defun bh/remove-empty-drawer-on-clock-out ()
  (interactive)
  (save-excursion
    (beginning-of-line 0)
    (org-remove-empty-drawer-at "LOGBOOK" (point))))
 (defun bh/clock-in-to-next (kw)
  "Switch a task from TODO to NEXT when clocking in.
Skips capture tasks, projects, and subprojects.
Switch projects and subprojects from NEXT back to TODO"
  (when (not (and (boundp 'org-capture-mode) org-capture-mode))
    (cond
     ((and (member (org-get-todo-state) (list "TODO"))
           (bh/is-task-p))
      "NEXT")
     ((and (member (org-get-todo-state) (list "NEXT"))
           (bh/is-project-p))
      "TODO"))))

(defun bh/punch-in (arg)
  "Start continuous clocking and set the default task to the
selected task.  If no task is selected set the Organization task
as the default task."
  (interactive "p")
  (setq bh/keep-clock-running t)
  (if (equal major-mode 'org-agenda-mode)
      ;;
      ;; We're in the agenda
      ;;
      (let* ((marker (org-get-at-bol 'org-hd-marker))
             (tags (org-with-point-at marker (org-get-tags-at))))
        (if (and (eq arg 4) tags)
            (org-agenda-clock-in '(16))
          (bh/clock-in-organization-task-as-default)))
    ;;
    ;; We are not in the agenda
    ;;
    (save-restriction
      (widen)
      ; Find the tags on the current task
      (if (and (equal major-mode 'org-mode) (not (org-before-first-heading-p)) (eq arg 4))
          (org-clock-in '(16))
        (bh/clock-in-organization-task-as-default)))))

(defun bh/punch-out ()
  (interactive)
  (setq bh/keep-clock-running nil)
  (when (org-clock-is-active)
    (org-clock-out))
  (org-agenda-remove-restriction-lock))

(defun bh/clock-in-default-task ()
  (save-excursion
    (org-with-point-at org-clock-default-task
      (org-clock-in))))

(defun bh/clock-in-parent-task ()
  "Move point to the parent (project) task if any and clock in"
  (let ((parent-task))
    (save-excursion
      (save-restriction
        (widen)
        (while (and (not parent-task) (org-up-heading-safe))
          (when (member (nth 2 (org-heading-components)) org-todo-keywords-1)
            (setq parent-task (point))))
        (if parent-task
            (org-with-point-at parent-task
              (org-clock-in))
          (when bh/keep-clock-running
            (bh/clock-in-default-task)))))))

(defun bh/clock-in-organization-task-as-default ()
  (interactive)
  (org-with-point-at (org-id-find bh/organization-task-id 'marker)
    (org-clock-in '(16))))

(defun bh/clock-out-maybe ()
  (when (and bh/keep-clock-running
             (not org-clock-clocking-in)
             (marker-buffer org-clock-default-task)
             (not org-clock-resolving-clocks-due-to-idleness))
    (bh/clock-in-parent-task)))

(defun bh/clock-in-task-by-id (id)
  "Clock in a task by id"
  (org-with-point-at (org-id-find id 'marker)
    (org-clock-in nil)))

(defun bh/clock-in-last-task (arg)
  "Clock in the interrupted task if there is one
Skip the default task and get the next one.
A prefix arg forces clock in of the default task."
  (interactive "p")
  (let ((clock-in-to-task
         (cond
          ((eq arg 4) org-clock-default-task)
          ((and (org-clock-is-active)
                (equal org-clock-default-task (cadr org-clock-history)))
           (caddr org-clock-history))
          ((org-clock-is-active) (cadr org-clock-history))
          ((equal org-clock-default-task (car org-clock-history)) (cadr org-clock-history))
          (t (car org-clock-history)))))
    (widen)
    (org-with-point-at clock-in-to-task
      (org-clock-in nil))))

(defun bh/org-auto-exclude-function (tag)
  "Automatic task exclusion in the agenda with / RET"
  (and (cond
	((string= tag "@home")
	 t)
	((string= tag "purchase")
	 t)
       ((string= tag "personal")
	t)
       )
       (concat "-" tag)))

(defun ndb/org-get-target-headline (&optional prompt)
  "Prompt for a location in an org file and jump to it.

This is for promping for refile targets when doing captures."
    (let* ((target (save-excursion
                     (org-refile-get-location prompt nil nil t)))
           (file (nth 1 target))
           (pos (nth 3 target))
           )
    (with-current-buffer (find-file-noselect file)
        (goto-char pos)
        (org-end-of-subtree)
        (org-return)
	)))

(defun ndb/start-in-agenda ()
  (org-agenda nil " ")
  (delete-other-windows)
  )

(defun ndb/insert-created-timestamp ()
  "Insert a CREATED property using org-expiry.el for TODO entries"
(save-excursion
  (org-expiry-insert-created)
  (show-all)
))

(defun ndb/clock-in-to-in-progress (kw)
  "Switch a task from TODO to IN-PROGRESS when clocking in.
Skips capture tasks, projects, and subprojects.
Switch projects and subprojects from NEXT back to TODO"
  (when (not (and (boundp 'org-capture-mode) org-capture-mode))
    (cond
     ((and (member (org-get-todo-state) (list "TODO" "NEXT"))
           (bh/is-task-p))
      "IN-PROGRESS")
     ((and (member (org-get-todo-state) (list "TODO" "NEXT"))
           (bh/is-project-p))
      "IN-PROGRESS"))))

(defun bh/restrict-to-file-or-follow (arg)
  "Set agenda restriction to 'file or with argument invoke follow mode.
I don't use follow mode very often but I restrict to file all the time
so change the default 'F' binding in the agenda to allow both"
  (interactive "p")
  (setq ndb/hide-todo-tasks nil)
  (if (equal arg 4)
      (org-agenda-follow-mode)
    (widen)
    (bh/set-agenda-restriction-lock 4)
    (org-agenda-redo)
    (beginning-of-buffer)))

(defun ndb/mark-next-parent-tasks-todo ()
"Visit each parent task and change state"
(let ((mystate (or (and (fboundp 'org-state) state) (nth 2 (org-heading-components)))))
    (when mystate
      (save-excursion
        (while (org-up-heading-safe)
	  (when (and
		 (bh/is-project-p)
		     (and
		      (not (member (org-get-todo-state) (list (ndb/get-project-state))))
		      ;;(not (member (org-get-todo-state) (list "MEETING")))
			   )
	    (org-todo (ndb/get-project-state))
	    ;;(message (ndb/get-project-state));;)
         ;; (when (member (nth 2 (org-heading-components)) (list "TODO"))
	;;(org-todo "NEXT")
	)))))))

(defun ndb/get-project-state ()
  "Visit each subtask and return the project state
If all child tasks are TODO, mark parent TODO
If any child tasks are NEXT, mark parent NEXT
If any child tasks are IN-PROGRESS, mark parent IN-PROGRESS"
  (save-restriction
    (widen)
    (save-excursion
      (let (subtree-end (org-end-of-subtree t))
	(forward-line 1)
      (cond
       ((re-search-forward "^\\*+ IN-PROGRESS " subtree-end t) "IN-PROGRESS")
       ((re-search-forward "^\\*+ WAITING " subtree-end t) "IN-PROGRESS")
       ((re-search-forward "^\\*+ HOLD " subtree-end t) "IN-PROGRESS")
       ((re-search-forward "^\\*+ NEXT " subtree-end t) "NEXT")
       (t "TODO"))
	)
      )))

(defun ndb/skip-projects ()
  "Skip projects.
Skip project and sub-projects"
  (save-restriction
    (widen)
    (if (bh/is-project-p)
	(save-excursion (or (outline-next-heading) (point-max)))
      (if (ndb/skip-todo-task) (save-excursion (org-end-of-subtree t)) nil)
    )
    )
  )

(defun ndb/skip-projects-and-project-subtasks ()
  "Skip Project and Project Sub-Tasks."
  (save-restriction
    (widen)
    (if (bh/is-project-p)
	(save-exursion (or (outline-next-heading) (point-max)))
      (if (ndb/skip-todo-task) (save-exursion (org-end-of-subtree t)) nil)
      )
    )
  )

(defun ndb/toggle-hide-todo (arg)
  (interactive "p")
  (if ndb/hide-todo-tasks (setq ndb/hide-todo-tasks nil) (setq ndb/hide-todo-tasks t))
  (org-agenda-redo)
  )

(defun ndb/skip-non-stuck-projects ()
  "Skip trees that are not stuck projects"
  ;;(bh/list-sublevels-for-projects-indented)
  (save-restriction
    (widen)
    (let ((next-headline (save-excursion (or (outline-next-heading) (point-max)))))
      (if (bh/is-project-p)
          (let* ((subtree-end (save-excursion (org-end-of-subtree t)))
                 (has-next ))
            (save-excursion
              (forward-line 1)
              (while (and (not has-next) (< (point) subtree-end) (re-search-forward "^\\*+ NEXT " subtree-end t))
                (unless (member "WAITING" (org-get-tags-at))
                  (setq has-next t))))
            (if has-next
                next-headline
              nil)) ; a stuck project, has subtasks but no next task
        next-headline))))

(defun ndb/skip-todo-task ()
  (cond
   ((and (member (org-get-todo-state) (list "TODO")) ndb/hide-todo-tasks) t)
   ((and (member (org-get-todo-state) (list "WAITING")) bh/hide-scheduled-and-waiting-next-tasks) t)
   ((org-is-habit-p) t)
;;   ((and (member (org-get-todo-state) (list "HOLD")) ndb/hide-todo-tasks) t)
   (t nil)
   )
  )

(defun ndb/skip-non-projects ()
  "Skip trees that are not projects"
  (interactive)
  (bh/list-sublevels-for-projects-indented)
  (save-restriction
    (widen)
    (let ((subtree-end (save-excursion (org-end-of-subtree t))))
      (cond
       ((and (bh/is-project-p) (not (ndb/skip-todo-task))) nil)
       ((and (bh/is-project-subtree-p) (not (bh/is-task-p)) (not (ndb/skip-todo-task))) nil)
       (t subtree-end)
       )
      )
    )
  )

(defun ndb/skip-project-and-subproject ()
  "Show non-project tasks.
Skip project and sub-projects tasks, and habits."
  (save-restriction
    (widen)
    (let ((subtree-end (save-excursion (org-end-of-subtree t))))
      (cond
       ((bh/is-task-p) nil)
       ;;((bh/is-project-subtree-p) nil)
       ;;((bh/is-subproject-p) nil)
       ;;((bh/is-project-p) subtree-end)
       ;;((org-is-habit-p) subtree-end)
       (t subtree-end)))))

;; (defun ndb/skip-non-current-tasks ()
;;   "Skip tasks which are not Next or In-Progress"
;;   (save-restriction
;;     (widen)
;;         (let ((subtree-end (save-excursion (org-end-of-subtree t))))
;;           (cond
;;            ((bh/is-project-p)
;;             nil)
;;            ((and (bh/is-project-subtree-p) (not (bh/is-task-p)))
;;             nil)
;;            (t
;;             subtree-end))))
;;     (save-excursion (org-end-of-subtree t))))


;;   (defun bh/skip-non-stuck-projects ()
;;   "Skip trees that are not stuck projects"
;;   ;;(bh/list-sublevels-for-projects-indented)
;;   (save-restriction
;;     (widen)
;;     (let ((next-headline (save-excursion (or (outline-next-heading) (point-max)))))
;;       (if (bh/is-project-p)
;;           (let* ((subtree-end (save-excursion (org-end-of-subtree t)))
;;                  (has-next ))
;;             (save-excursion
;;               (forward-line 1)
;;               (while (and (not has-next) (< (point) subtree-end) (re-search-forward "^\\*+ NEXT " subtree-end t))
;;                 (unless (member "WAITING" (org-get-tags-at))
;;                   (setq has-next t))))
;;             (if has-next
;;                 next-headline
;;               nil)) ; a stuck project, has subtasks but no next task
;;         next-headline))))

;;   )

;; Load my org-agenda files
(setq org-agenda-files
  (quote
    ("~/org")
  )
)

;; Overwrite the current window with the agenda
(setq org-agenda-window-setup 'current-window)

(global-set-key "\C-cl" 'org-store-link)
(global-set-key "\C-ca" 'org-agenda)
(global-set-key "\C-cb" 'org-iswitchb)

;; Agenda clock report parameters
(setq org-agenda-clockreport-parameter-plist
      (quote (:link t :maxlevel 5 :fileskip0 t :compact t :narrow 80)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Set line formagt to give enough space for Category
(setq org-agenda-prefix-format
       (quote
	((agenda . " %i %-18:c%?-12t% s")
	 (timeline . "  % s")
	 (todo . " %i %-18:c")
	 (tags . " %i %-18:c")
	 (search . " %i %-18:c")
	 )
	)
       )
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Default to hide tasks
(defvar bh/hide-scheduled-and-waiting-next-tasks t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Default to hide todo tasks
(defvar ndb/hide-todo-tasks t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Persist agenda filters across agenda views
(setq org-agenda-persistent-filter t)

;; Start the weekly agenda on Monday
(setq org-agenda-start-on-weekday 1)

;; Skip scheduled and complete
(setq org-agenda-skip-scheduled-if-done nil)
(setq org-agenda-skip-deadline-if-done t)

;; Enable display of the time grid so we can see the marker for the current time
(setq org-agenda-time-grid (quote ((daily today remove-match)
                                   #("----------------" 0 16 (org-heading t))
                                   (0900 1100 1300 1500 1700))))

;; Display tags farther right
(setq org-agenda-tags-column -120)

;; Always hilight the current agenda line
(add-hook 'org-agenda-mode-hook
          '(lambda () (hl-line-mode 1))
          'append)

;; Set agenda to day mode by default
(setq org-agenda-span 'day)

;; Needed to override definition of "stuck project"
(setq org-stuck-projects (quote ("" nil nil "")))

(setq org-agenda-auto-exclude-function 'bh/org-auto-exclude-function)


;;;;;;;;;;;;;;;;;;;
;; Org Agenda Hooks

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Narrows Agenda View to only selected project tasks
(add-hook 'org-agenda-mode-hook
          '(lambda () (org-defkey org-agenda-mode-map "P" 'bh/narrow-to-project))
          'append)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Expands narrowed selection
(add-hook 'org-agenda-mode-hook
          '(lambda () (org-defkey org-agenda-mode-map "W" (lambda () (interactive) (setq bh/hide-scheduled-and-waiting-next-tasks t) (setq ndb/hide-todo-tasks t) (bh/widen))))
          'append)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Set agenda restriction to subtree of tag or file with C-u
(add-hook 'org-agenda-mode-hook
          '(lambda () (org-defkey org-agenda-mode-map "\C-c\C-x<" 'bh/set-agenda-restriction-lock))
          'append)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Set restrict to file or follow with C-u
(add-hook 'org-agenda-mode-hook
          '(lambda () (org-defkey org-agenda-mode-map "F" 'bh/restrict-to-file-or-follow))
          'append)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Set restrict to file or follow with C-u
(add-hook 'org-agenda-mode-hook
          '(lambda () (org-defkey org-agenda-mode-map "\C-cp" 'ndb/toggle-hide-todo))
          'append)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Custom agenda command definitions
(setq org-agenda-custom-commands
      (quote (("N" "Notes" 
	       ((tags "NOTE"
		      ((org-agenda-overriding-header "Notes")
		       (org-tags-match-list-sublevels t))
		      )))
		("h" "Habits" tags-todo "STYLE=\"habit\""
               ((org-agenda-overriding-header "Habits")
                (org-agenda-sorting-strategy
                 '(todo-state-down effort-up category-keep))))

		(" " "Agenda"
		 (
		  ;;(agenda "" ((org-agenda-log-mode t)))
		  (agenda ""
		   
		    ((org-agenda-sorting-strategy '(habit-down time-up deadline-up scheduled-up)))
		   )
		  (tags "GENERAL"
			((org-agenda-overriding-header "General Tasks")
			 (org-tags-match-list-sublevels t)))
		  
		  ;; Displays all current projects
		  (tags-todo "-PURCHASE-HOLD-CANCELLED/!"
			     (
			      (org-agenda-overriding-header "Projects")
			      (org-agenda-skip-function 'ndb/skip-non-projects)
			      (org-tags-match-list-sublevels t)
			      (org-agenda-sorting-strategy '(todo-state-down deadline-down priority-down))
			     )
		  )	
	  
		  ;; All tasks which are in progress / Next or scheduled this week
		  (tags-todo "-PURCHASE-HOLD-CANCELLED/!"
			     ((org-agenda-overriding-header "Tasks")
			     ;;(org-agenda-skip-function 'bh/skip-non-subprojects)
			      (org-agenda-skip-function 'ndb/skip-projects)
			      (org-tags-match-list-sublevels t)			      
			      ;;(org-agenda-todo-ignore-scheduled bh/hide-scheduled-and-waiting-next-tasks)
			      ;;(org-agenda-todo-ignore-deadlines bh/hide-scheduled-and-waiting-next-tasks)
			      ;;(org-agenda-todo-ignore-with-date bh/hide-scheduled-and-waiting-next-tasks)
			      (org-agenda-sorting-strategy '(todo-state-down deadline-up category-up effort-up priority-down))))
		  ;; Waiting tasks
		  (tags-todo "+WAITING|+HOLD/!"
			     ((org-agenda-overriding-header (concat "Waiting and Postponed Tasks"
								    (if bh/hide-scheduled-and-waiting-next-tasks
									""
								      " (including WAITING and SCHEDULED tasks)")))
			      ;; (org-agenda-skip-function 'bh/skip-non-tasks) ;; defun doesn't exist
			      (org-tags-match-list-sublevels t)
			      ;; (org-agenda-todo-ignore-scheduled bh/hide-scheduled-and-waiting-next-tasks)
			      ;; (org-agenda-todo-ignore-deadlines bh/hide-scheduled-and-waiting-next-tasks)
			      ))

		  ;; Not started projects
		  ;; (tags-todo "-CANCELLED/!"
		  ;; 	     ((org-agenda-overriding-header "Stuck Projects")
		  ;; 	      (org-agenda-skip-function 'bh/skip-non-stuck-projects)
		  ;; 	      (org-agenda-sorting-strategy
 		  ;; 	       '(category-keep))))


		  ;; Items which need to be refiled
		  (tags-todo "+PURCHASE/!"
			((org-agenda-overriding-header "Purchases")
			 (org-agenda-skip-function 'ndb/skip-projects)
			 (org-tags-match-list-sublevels t)))
		  
		  (tags "REFILE"
			((org-agenda-overriding-header "Tasks to Refile")
			 (org-tags-match-list-sublevels nil)))
		  (tags "MEETING"
			((org-agenda-overriding-header "Meetings")
			 (org-tags-match-list-sublevels nil)))
		  
		  ;; (tags-todo "-CANCELLED/!NEXT"
		  ;;            ((org-agenda-overriding-header (concat "Project Next Tasks"
		  ;;                                                   (if bh/hide-scheduled-and-waiting-next-tasks
		  ;;                                                       ""
		  ;;                                                     " (including WAITING and SCHEDULED tasks)")))
		  ;;             (org-agenda-skip-function 'bh/skip-projects-and-habits-and-single-tasks)
		  ;;             (org-tags-match-list-sublevels t)
		  ;;             (org-agenda-todo-ignore-scheduled bh/hide-scheduled-and-waiting-next-tasks)
		  ;;             (org-agenda-todo-ignore-deadlines bh/hide-scheduled-and-waiting-next-tasks)
		  ;;             (org-agenda-todo-ignore-with-date bh/hide-scheduled-and-waiting-next-tasks)
		  ;;             (org-agenda-sorting-strategy
		  ;;              '(todo-state-down effort-up category-keep))))
		  ;; (tags-todo "-REFILE-CANCELLED-WAITING-HOLD/!"
		  ;;            ((org-agenda-overriding-header (concat "Project Subtasks"
		  ;;                                                   (if bh/hide-scheduled-and-waiting-next-tasks
		  ;;                                                       ""
		  ;;                                                     " (including WAITING and SCHEDULED tasks)")))
		  ;;             (org-agenda-skip-function 'bh/skip-non-project-tasks)
		  ;;             (org-agenda-todo-ignore-scheduled bh/hide-scheduled-and-waiting-next-tasks)
		  ;;             (org-agenda-todo-ignore-deadlines bh/hide-scheduled-and-waiting-next-tasks)
		  ;;             (org-agenda-todo-ignore-with-date bh/hide-scheduled-and-waiting-next-tasks)
		  ;;             (org-agenda-sorting-strategy
		  ;;              '(category-keep))))
		  (tags "-REFILE/"
		         ((org-agenda-overriding-header "Tasks to Archive")
		          (org-agenda-skip-function 'bh/skip-non-archivable-tasks)
		          (org-tags-match-list-sublevels nil)))
		  )
		 nil)

		;; Set filter on personal only?
		 ("p" "Personal"
		 (
		  (agenda ""
		   
		    ((org-agenda-sorting-strategy '(habit-down time-up deadline-up scheduled-up)))
		    )		  
		  (tags-todo "-CANCELLED+PRIORITY/!"
			     (
			      (org-agenda-overriding-header "Priority Tasks")
			      (org-tags-match-list-sublevels t)
			      )
			     )
		  (tags-todo "+PURCHASE/!"
			((org-agenda-overriding-header "Purchases")
			 (org-agenda-skip-function 'ndb/skip-projects)
			 (org-tags-match-list-sublevels t)))
	  
		  ;; All tasks which are in progress / Next or scheduled this week
		  (tags-todo "-PURCHASE-HOLD-CANCELLED/!"
			     ((org-agenda-overriding-header "Tasks")
			     ;;(org-agenda-skip-function 'bh/skip-non-subprojects)
			      (org-agenda-skip-function 'ndb/skip-projects)
			      (org-tags-match-list-sublevels t)			      
			      ;;(org-agenda-todo-ignore-scheduled bh/hide-scheduled-and-waiting-next-tasks)
			      ;;(org-agenda-todo-ignore-deadlines bh/hide-scheduled-and-waiting-next-tasks)
			      ;;(org-agenda-todo-ignore-with-date bh/hide-scheduled-and-waiting-next-tasks)
			      (org-agenda-sorting-strategy '(todo-state-down deadline-up category-up effort-up priority-down))))
		  ;; Waiting tasks
		  (tags-todo "+WAITING|+HOLD/!"
			     ((org-agenda-overriding-header (concat "Waiting and Postponed Tasks"
								    (if bh/hide-scheduled-and-waiting-next-tasks
									""
								      " (including WAITING and SCHEDULED tasks)")))
			      ;; (org-agenda-skip-function 'bh/skip-non-tasks) ;; defun doesn't exist
			      (org-tags-match-list-sublevels t)
			      ;; (org-agenda-todo-ignore-scheduled bh/hide-scheduled-and-waiting-next-tasks)
			      ;; (org-agenda-todo-ignore-deadlines bh/hide-scheduled-and-waiting-next-tasks)
			      ))

		  		  ;; Displays all current projects
		  (tags-todo "-PURCHASE-HOLD-CANCELLED/!"
			     (
			      (org-agenda-overriding-header "Projects")
			      (org-agenda-skip-function 'ndb/skip-non-projects)
			      (org-tags-match-list-sublevels t)
			      (org-agenda-sorting-strategy '(todo-state-down deadline-down priority-down))
			     )
		  )	
		  ;; Not started projects
		  (tags-todo "-CANCELLED/!"
		  	     ((org-agenda-overriding-header "Stalled Projects")
		  	      (org-agenda-skip-function 'bh/skip-non-stuck-projects)
		  	      (org-agenda-sorting-strategy
 		  	       '(category-keep))))		  
		  (tags "REFILE"
			((org-agenda-overriding-header "Tasks to Refile")
			 (org-tags-match-list-sublevels nil)))
		  
		   (tags "-REFILE/"
		        ((org-agenda-overriding-header "Tasks to Archive")
		         (org-agenda-skip-function 'bh/skip-non-archivable-tasks)
		  
		  (org-tags-match-list-sublevels nil)))
		   )
		  nil)
		 
               )))

;; Silence the usual message: Get more info using the about page via C-h C-a.
(setq inhibit-startup-message t)

(defun display-startup-echo-area-message ()
  "The message that is shown after ‘user-init-file’ is loaded."
  (message
      (concat "Welcome "      user-full-name
              "! Emacs "      emacs-version
              "; Org-mode "   (org-version)
              "; System "     (symbol-name system-type)
              "/"             (system-name)
              "; Time "       (emacs-init-time))))

;; This package requires the fonts included with all-the-icons to be installed. Run M-x all-the-icons-install-fonts to do so.
;; The modeline looks really nice with doom-themes, e.g., doom-solarised-light.
(use-package all-the-icons
:ensure t)
(use-package doom-modeline
  :defer nil
  :config (doom-modeline-mode))

  ;; Use minimal height so icons still fit; modeline gets slightly larger when
  ;; buffer is modified since the "save icon" shows up.  Let's disable the icon.
  ;; Let's also essentially disable the hud bar, a sort of progress-bar on where we are in the buffer.
  (setq doom-modeline-height 1)
  (setq doom-modeline-buffer-state-icon nil)
  (setq doom-modeline-hud nil)
  (setq doom-modeline-bar-width 1)

  ;; Show 3 Flycheck numbers: “red-error / yellow-warning / green-info”, which
  ;; we can click to see a listing.
  ;; If not for doom-modeline, we'd need to use flycheck-status-emoji.el.
  (setq doom-modeline-checker-simple-format nil)

  ;; Don't display the buffer encoding, E.g., “UTF-8”.
  (setq doom-modeline-buffer-encoding nil)

  (set-face-attribute 'mode-line nil
                  :background "#353644"
                  :foreground "white"
                  :box '(:line-width 6 :color "#353644")
                  :overline nil
                  :underline nil)

  (set-face-attribute 'mode-line-inactive nil
                  :background "#565063"
                  :foreground "white"
                  :box '(:line-width 6 :color "#565063")
                  :overline nil
                  :underline nil)
  ;; Inactive buffers' modeline is greyed out.
  ;; (let ((it "Source Code Pro Light" ))
  ;;   (set-face-attribute 'mode-line nil :family it :height 100)
  ;;   (set-face-attribute 'mode-line-inactive nil :family it :height 100))

;; Treat all themes as safe; no query before use.
(setf custom-safe-themes t)

;; Nice looking themes ^_^
(use-package vs-dark-theme :defer t)

(setq doom-modeline-minor-modes t)
(use-package minions
  :defer nil
  :init (minions-mode))

;; A quick hacky way to add stuff to doom-modeline is to add to the mode-line-process list.
;; E.g.:  (add-to-list 'mode-line-process '(:eval (format "%s" (count-words (point-min) (point-max)))))
;; We likely want to add this locally, to hooks on major modes.

;; If not for doom-modeline, we'd need to use fancy-battery-mode.el.
(display-battery-mode +1)

(unless noninteractive
  (tool-bar-mode   -1)  ;; No large icons please
  (scroll-bar-mode -1)  ;; No visual indicator please
  (menu-bar-mode   -1)  ;; The Mac OS top pane has menu options
  (tooltip-mode -1))
