CREATE OR REPLACE
PACKAGE BODY opencmsAccess IS
---------------------------------------------------------------------------------------------------
-- function checks if user has access to create the resource, return binary number: 1=true, 0=false
---------------------------------------------------------------------------------------------------
  FUNCTION accessCreate(pUserID NUMBER, pProjectID NUMBER, pResourceID NUMBER) RETURN NUMBER IS
    vResProjectID NUMBER;
    curNextResource userTypes.anyCursor;
    recResource cms_resources%ROWTYPE;
    vNextPath cms_resources.resource_name%TYPE;
    vLockedInProject NUMBER;
    vOnlineProject NUMBER;
    vLockedBy NUMBER;
  BEGIN
    -- project = online-project => false
    vOnlineProject := opencmsProject.onlineProject(pProjectID).project_id;
    IF pProjectID = vOnlineProject THEN   
      RETURN 0;
    END IF;
    -- no access for projekt => false
    IF accessProject(pUserID, pProjectID) = 0 THEN   
      RETURN 0;
    END IF;
    -- resource does not belong to the projekt with project_id = pProjectId => false
    BEGIN
      select max(p.project_id), max(r.resource_name), max(r.project_id), max(r.locked_by) 
             into vResProjectID, vNextPath, vLockedInProject, vLockedBy
             from cms_resources r, cms_projectresources p
             where resource_id = pResourceID
             and r.resource_name like concat(p.resource_name, '%')
             and p.project_id in (pProjectID, vOnlineProject);
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
      	vLockedInProject := null;
        vResProjectID := null;
        vNextPath := null;
    END;
    IF vResProjectID != pProjectId THEN  
      RETURN 0;
    END IF;
    -- resource locked by another user => false
    IF vLockedBy != opencmsConstants.C_UNKNOWN_ID AND
    	(vLockedBy != pUserID OR vLockedInProject != pProjectID) THEN
        RETURN 0;
    END IF;
    -- for current resource no write access Other/Owner/Group => false
    IF (accessOwner(pUserID, pProjectID, vNextPath, opencmsConstants.C_ACCESS_OWNER_WRITE) = 0
        AND accessGroup(pUserID, pProjectID, vNextPath, opencmsConstants.C_ACCESS_GROUP_WRITE) = 0
        AND accessOther(pUserID, pProjectID, vNextPath, opencmsConstants.C_ACCESS_PUBLIC_WRITE) = 0) THEN 
      RETURN 0;
    END IF;
    -- select super resources
    vNextPath := opencmsResource.getParent(vNextPath);
    -- access for resource and super resources
    --WHILE vNextPath IS NOT NULL
    IF vNextPath IS NOT NULL THEN
      LOOP
        -- for all super resources read access Other/Owner/Group
      	IF (accessOwner(pUserID, pProjectID, vNextPath, opencmsConstants.C_ACCESS_OWNER_READ) = 1
          OR accessGroup(pUserID, pProjectID, vNextPath, opencmsConstants.C_ACCESS_OWNER_READ) = 1
          OR accessOther(pUserID, pProjectID, vNextPath, opencmsConstants.C_ACCESS_OWNER_READ) = 1) THEN
          curNextResource := opencmsResource.readFolder(pUserId, pProjectID, vNextPath);
          FETCH curNextResource INTO recResource;
          IF curNextResource%NOTFOUND THEN
            recResource := NULL;
          END IF;
          CLOSE curNextResource;
          -- resource locked by another user => false
          IF recResource.locked_by != opencmsConstants.C_UNKNOWN_ID AND
             (recResource.locked_by != pUserID OR vLockedInProject != pProjectID) THEN
            RETURN 0;
          END IF;
          -- search next folder
          vNextPath := opencmsResource.getParent(recResource.resource_name);
        ELSE
          RETURN 0;
        END IF;
        IF (opencmsResource.getParent(vNextPath)) IS NULL THEN
          -- don't check the access for the root-folder
          EXIT;
        END IF;
      END LOOP;
    END IF;
    RETURN 1;
  END accessCreate;
---------------------------------------------------------------------------------------------------
-- function checks if user has access to lock the resource, return binary number: 1=true, 0=false
---------------------------------------------------------------------------------------------------
  FUNCTION accessLock(pUserID NUMBER, pProjectID NUMBER, pResourceID NUMBER) RETURN NUMBER IS
    vResProject NUMBER;
    vResPath cms_resources.resource_name%TYPE;
    curResource userTypes.anyCursor;
    recResource cms_resources%ROWTYPE;
    vOnlineProject NUMBER;
    vLockedInProject NUMBER;
    vProjectFlag NUMBER;
  BEGIN
    -- project = online-Project => false
    vOnlineProject := opencmsProject.onlineProject(pProjectID).project_id;
    IF pProjectID = vOnlineProject THEN
      RETURN 0;
    END IF;
    -- not accessProject => false
    IF accessProject(pUserID, pProjectID) = 0 THEN
      RETURN 0;
    END IF;
    BEGIN
      select max(p.project_id), max(r.resource_name) into vResProject, vResPath
             from cms_resources r, cms_projectresources p
             where resource_id = pResourceID
             and r.resource_name like concat(p.resource_name, '%')
             and p.project_id in (pProjectID, vOnlineProject);
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        vResProject := NULL;
        vResPath := NULL;
    END;
    -- resource.project_id != project_id => false
    IF vResProject != pProjectID THEN
      RETURN 0;
    END IF;
    -- if resource.getParent = NULL => true
    vResPath := opencmsResource.getParent(vResPath);
    IF vResPath IS NULL THEN
      RETURN 1;
    ELSE
      -- for resource and all super resources
      --WHILE vResPath IS NOT NULL
      LOOP
        curResource := opencmsResource.readFolder(pUserID, pProjectId, vResPath);
        FETCH curResource INTO recResource;
        IF curResource%NOTFOUND THEN
          recResource := NULL;
        END IF;
        CLOSE curResource;
        select project_id into vLockedInProject 
               from cms_resources 
               where resource_id = recResource.resource_id;
        select project_flags into vProjectFlag from cms_projects where project_id = pProjectId;
        -- resource.locked_by not in (C_UNKNOWN_ID, pUserID) => false
        IF recResource.locked_by NOT IN (opencmsConstants.C_UNKNOWN_ID, pUserID) 
           OR (recResource.locked_by != opencmsConstants.C_UNKNOWN_ID AND vLockedInProject != pProjectId
           AND vProjectFlag != opencmsConstants.C_PROJECT_STATE_INVISIBLE) THEN
          RETURN 0;
        END IF;
        vResPath := opencmsResource.getParent(vResPath);
        IF opencmsResource.getParent(vResPath) IS NULL THEN
          -- don't check the access for the root-folder
          EXIT;
        END IF;
      END LOOP;
    END IF;
    RETURN 1;
  END accessLock;
---------------------------------------------------------------------------------------------------
-- function checks if user has access to unlock the resource, return binary number: 1=true, 0=false
---------------------------------------------------------------------------------------------------
  FUNCTION accessUnlock(pUserID NUMBER, pProjectID NUMBER, pResourceID NUMBER) RETURN NUMBER IS
    vResProject NUMBER;
    vResPath cms_resources.resource_name%TYPE;
    curResource userTypes.anyCursor;
    recResource cms_resources%ROWTYPE;
    vOnlineProject NUMBER;
  BEGIN
    -- project = online-Project => false
    vOnlineProject := opencmsProject.onlineProject(pProjectID).project_id;
    IF pProjectID = vOnlineProject THEN
      RETURN 0;
    END IF;
    -- not accessProject => false
    IF accessProject(pUserID, pProjectID) = 0 THEN
      RETURN 0;
    END IF;
    BEGIN
      select max(p.project_id), max(r.resource_name)
             into vResProject, vResPath
             from cms_resources r, cms_projectresources p
             where resource_id = pResourceID
             and r.resource_name like concat(p.resource_name, '%')
             and p.project_id in (pProjectID, vOnlineProject);
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        vResProject := NULL;
        vResPath := NULL;
    END;
    -- resource.project_id != project_id => false
    IF vResProject != pProjectID THEN
      RETURN 0;
    END IF;
    -- if resource.getParent = NULL => true
    vResPath := opencmsResource.getParent(vResPath);
    IF vResPath IS NULL THEN
      RETURN 1;
    ELSE
      -- for resource and all super resources
      --WHILE vResPath IS NOT NULL
      LOOP
        curResource := opencmsResource.readFolder(pUserID, pProjectId, vResPath);
        FETCH curResource INTO recResource;
        IF curResource%NOTFOUND THEN
          recResource := NULL;
        END IF;
        CLOSE curResource;
        -- resource.locked_by not in (C_UNKNOWN_ID, pUserID) => false
        IF recResource.locked_by != opencmsConstants.C_UNKNOWN_ID THEN
          RETURN 0;
        END IF;
        vResPath := opencmsResource.getParent(vResPath);
        IF opencmsResource.getParent(vResPath) IS NULL THEN
          -- don't check the access for the root-folder
          EXIT;
        END IF;
      END LOOP;
    END IF;
    RETURN 1;
  END accessUnlock;
---------------------------------------------------------------------------------------------------
-- function checks if user has access for the project, return binary number: 1=true, 0=false
---------------------------------------------------------------------------------------------------
  FUNCTION accessProject(pUserID NUMBER, pProjectID NUMBER) RETURN NUMBER IS
    vProjFlags NUMBER;
    vProjOwner NUMBER;
    vProjGroup NUMBER;
    vProjManager NUMBER;
    vAdminId NUMBER;
    curGroups userTypes.anyCursor;
    recGroupID cms_groups.group_id%TYPE;
    recGroupName cms_groups.group_name%TYPE;
  BEGIN
    -- project_id = online-project => true
    IF pProjectID = opencmsProject.onlineProject(pProjectID).project_id THEN
      RETURN 1;
    END IF;
    BEGIN
      select project_flags, user_id, group_id, managergroup_id
           into vProjFlags, vProjOwner, vProjGroup, vProjManager
           from cms_projects
           where project_id = pProjectID;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RETURN 0;
    END;
    -- project_flags != C_PROJECT_STATE_UNLOCKED => false
    IF vProjFlags != opencmsConstants.C_PROJECT_STATE_UNLOCKED AND
	   vProjFlags != opencmsConstants.C_PROJECT_STATE_INVISIBLE THEN
      RETURN 0;
    END IF;
    -- user = owner or user isAdmin => true
    select group_id into vAdminId from cms_groups where group_name = opencmsConstants.C_GROUP_ADMIN;
    IF vProjOwner = pUserID OR opencmsGroup.userInGroup(pUserID, vAdminId) = 1 THEN
      RETURN 1;
    END IF;
    -- for all groups from getGroupsOfUser:
    -- group_id in (project.group_id, project.manager_group_id) => true
    curGroups := opencmsGroup.getGroupsOfUser(pUserID);
    LOOP
      FETCH curGroups INTO recGroupID, recGroupName;
      EXIT WHEN curGroups%NOTFOUND;
      IF recGroupID IN (vProjGroup, vProjManager) THEN
        CLOSE curGroups;
        RETURN 1;
      END IF;
    END LOOP;
    CLOSE curGroups;
    RETURN 0;
  END accessProject;
---------------------------------------------------------------------------------------------------
-- function checks if user has access to read the resource, return binary number: 1=true, 0=false
---------------------------------------------------------------------------------------------------
  FUNCTION accessRead(pUserID NUMBER, pProjectID NUMBER, pResourceName VARCHAR2) RETURN NUMBER IS
    curNextResource userTypes.anyCursor;
    recResource cms_resources%ROWTYPE;
    vNextPath cms_resources.resource_name%TYPE;
    vProjectId cms_resources.project_id%TYPE;
    vOnlineProject NUMBER;
  BEGIN
    IF pResourceName IS NULL THEN
      RETURN 0;
    END IF;
    BEGIN
      vOnlineProject := opencmsProject.onlineProject(pProjectId).project_id;
      IF pProjectID = vOnlineProject THEN
        select resource_name, project_id into vNextPath, vProjectId
               from cms_online_resources
               where resource_name = pResourceName;
      ELSE
        select max(p.project_id), max(r.resource_name) into vProjectId, vNextPath
             from cms_resources r, cms_projectresources p
             where r.resource_name = pResourceName
             and r.resource_name like concat(p.resource_name, '%')
             and p.project_id in (pProjectID, vOnlineProject);
      END IF;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        vNextPath := NULL;
    END;
    -- NOT accessProject => false
    IF accessProject(pUserID, vProjectID) = 0 THEN
      RETURN 0;
    END IF;
    -- for resource and all super resources
    WHILE vNextPath IS NOT NULL LOOP
      -- NOT (accessOther or accessOwner or accessGroup (read)) => false
      IF (accessOwner(pUserID, pProjectID, vNextPath, opencmsConstants.C_ACCESS_OWNER_READ) = 1
          OR accessGroup(pUserID, pProjectID, vNextPath, opencmsConstants.C_ACCESS_GROUP_READ) = 1
          OR accessOther(pUserID, pProjectID, vNextPath, opencmsConstants.C_ACCESS_PUBLIC_READ) = 1) THEN
        vNextPath := opencmsResource.getParent(vNextPath);
      ELSE
        RETURN 0;
      END IF;
    END LOOP;
    RETURN 1;
  END accessRead;
---------------------------------------------------------------------------------------------------
-- function checks if user has access to write the resource, return binary number: 1=true, 0=false
---------------------------------------------------------------------------------------------------
  FUNCTION accessWrite(pUserID NUMBER, pProjectID NUMBER, pResourceID NUMBER) RETURN NUMBER IS
    vResProjectID NUMBER;
    curNextResource userTypes.anyCursor;
    recResource cms_resources%ROWTYPE;
    vNextPath cms_resources.resource_name%TYPE;
    vLockedBy NUMBER;
    vOnlineProject NUMBER;
    vLockedInProject NUMBER;
  BEGIN
    -- project = online-project => false
    vOnlineProject := opencmsProject.onlineProject(pProjectID).project_id;
    IF pProjectID = vOnlineProject THEN
      RETURN 0;
    END IF;
    -- NOT accessProject => false
    IF accessProject(pUserID, pProjectID) = 0 THEN
      RETURN 0;
    END IF;
    BEGIN
      select a.project_id, b.resource_name, b.locked_by, b.project_id
             into vResProjectID, vNextPath, vLockedBy, vLockedInProject
             from (select max(p.project_id) project_id
                   from cms_resources r, cms_projectresources p
                   where resource_id = pResourceID
                   and r.resource_name like concat(p.resource_name, '%')
                   and p.project_id in (pProjectID, vOnlineProject)) a,
                   cms_resources b
             where b.resource_id = pResourceID;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        vResProjectId := null;
        vNextPath := null;
        vLockedBy := null;
    END;
-- the following check is disabled because there are problems
    -- not locked by user => false
    IF vLockedBy != pUserId THEN
      RETURN 0;
    ELSE
      -- not locked in current project => false
      IF vLockedInProject != pProjectId THEN
      	RETURN 0;
      END IF;
    END IF;
    -- resource.projectID != project_id => false
    IF vResProjectID != pProjectId THEN
      RETURN 0;
    END IF;
    -- for current resource no accessOther/Owner/Group => false
    IF (accessOwner(pUserID, pProjectID, vNextPath, opencmsConstants.C_ACCESS_OWNER_WRITE) = 0
        AND accessGroup(pUserID, pProjectID, vNextPath, opencmsConstants.C_ACCESS_GROUP_WRITE) = 0
        AND accessOther(pUserID, pProjectID, vNextPath, opencmsConstants.C_ACCESS_PUBLIC_WRITE) = 0) THEN
      RETURN 0;
    END IF;
    -- select super resources
    vNextPath := opencmsResource.getParent(vNextPath);
    -- check access for all super resources
    --WHILE vNextPath IS NOT NULL
    IF vNextPath IS NOT NULL THEN
      LOOP
         -- no accessOther/Owner/Group => false
        IF (accessOwner(pUserID, pProjectID, vNextPath, opencmsConstants.C_ACCESS_OWNER_READ) = 1
          OR accessGroup(pUserID, pProjectID, vNextPath, opencmsConstants.C_ACCESS_GROUP_READ) = 1
          OR accessOther(pUserID, pProjectID, vNextPath, opencmsConstants.C_ACCESS_PUBLIC_READ) = 1) THEN
          curNextResource := opencmsResource.readFolder(pUserId, pProjectID, vNextPath);
          FETCH curNextResource INTO recResource;
          IF curNextResource%NOTFOUND THEN
            recResource := NULL;
          END IF;
          CLOSE curNextResource;
          -- resource locked by another user => false
          IF recResource.locked_by NOT IN (opencmsConstants.C_UNKNOWN_ID, pUserID) THEN
            RETURN 0;
          END IF;
          -- search next folder
          vNextPath := opencmsResource.getParent(recResource.resource_name);
        ELSE
          RETURN 0;
        END IF;
        IF opencmsResource.getParent(vNextPath) IS NULL THEN
          -- don't check the access for the root-folder
          EXIT;
        END IF;
      END LOOP;
    END IF;
    RETURN 1;
  END accessWrite;
---------------------------------------------------------------------------------------------------
-- access defined by pAccess (read/write) for others return boolean
---------------------------------------------------------------------------------------------------
  FUNCTION accessOther(pUserID NUMBER, pProjectID NUMBER, pResourceName VARCHAR2, pAccess NUMBER) RETURN NUMBER IS
    vAccessFlag NUMBER;
    vOnlineProject NUMBER;
  BEGIN
    vOnlineProject := opencmsProject.onlineProject(pProjectId).project_id;
    IF pProjectID = vOnlineProject THEN
      select access_flags into vAccessFlag from cms_online_resources where resource_name = pResourceName;
    ELSE
      select access_flags into vAccessFlag from cms_resources where resource_name = pResourceName;
    END IF;
    IF bitand(vAccessFlag, pAccess) = pAccess THEN
      RETURN 1;
    END IF;
    RETURN 0;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN 0;
  END accessOther;
---------------------------------------------------------------------------------------------------
-- access defined by pAccess (read/write) for owner return boolean
---------------------------------------------------------------------------------------------------
  FUNCTION accessOwner(pUserID NUMBER, pProjectID NUMBER, pResourceName VARCHAR2, pAccess NUMBER) RETURN NUMBER IS
    vAccessFlag NUMBER;
    vOwnerID NUMBER;
    vAdminId NUMBER;
    vOnlineProject NUMBER;
  BEGIN
    select group_id into vAdminId from cms_groups where group_name = opencmsConstants.C_GROUP_ADMIN;
    IF opencmsGroup.userInGroup(pUserId, vAdminId) = 1 THEN
      RETURN 1;
    END IF;
    vOnlineProject := opencmsProject.onlineProject(pProjectId).project_id;
    IF pProjectID = vOnlineProject THEN
      select user_id, access_flags into vOwnerId, vAccessFlag
             from cms_online_resources where resource_name = pResourceName;
    ELSE
      select user_id, access_flags into vOwnerId, vAccessFlag
             from cms_resources where resource_name = pResourceName;
    END IF;
    IF vOwnerId = pUserId THEN
      IF bitand(vAccessFlag, pAccess) = pAccess THEN
        RETURN 1;
      END IF;
    END IF;
    RETURN 0;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN 0;
  END accessOwner;
---------------------------------------------------------------------------------------------------
-- access defined by pAccess (read/write) for group return boolean
---------------------------------------------------------------------------------------------------
  FUNCTION accessGroup(pUserID NUMBER, pProjectID NUMBER, pResourceName VARCHAR2, pAccess NUMBER) RETURN NUMBER IS
    vGroupId NUMBER;
    vAccessFlag NUMBER;
    vOnlineProject NUMBER;
  BEGIN
    vOnlineProject := opencmsProject.onlineProject(pProjectId).project_id;
    IF pProjectID = vOnlineProject THEN
      select group_id, access_flags into vGroupId, vAccessFlag
             from cms_online_resources
             where resource_name = pResourceName;
    ELSE
      select group_id, access_flags into vGroupId, vAccessFlag
             from cms_resources where resource_name = pResourceName;
    END IF;
    IF opencmsGroup.userInGroup(pUserID, vGroupId) = 1 THEN
      IF bitand(vAccessFlag, pAccess) = pAccess THEN
        RETURN 1;
      END IF;
    END IF;
    RETURN 0;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN 0;
  END accessGroup;
---------------------------------------------------------------------------------------------------
END;
/
