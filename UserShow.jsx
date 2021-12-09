  
import React, { useState, useEffect, useRef } from "react";
import { useHistory } from 'react-router-dom';
import Project from './Project';
import { motion } from 'framer-motion';
import Promise from 'bluebird'
import { successToast } from '../ToastAlerts';
import _ from "lodash";
import { options } from '../Fetches';
import { Responsive, WidthProvider } from "react-grid-layout";
import './user.scss';

const ResponsiveReactGridLayout = WidthProvider(Responsive);

const UserShow = ({ loggedInStatus, pageVariants, pageTransition, updateUser, maxProject }) => {
  const [width, setWidth] = useState(window.innerWidth);
  useEffect(() => {
    const handleWindowResize = () => setWidth(window.innerWidth)
    window.addEventListener("resize", handleWindowResize);
    return () => window.removeEventListener("resize", handleWindowResize);
   },[]);
  const history = useHistory();
  const defaultProps = {
    className: "layout",
    rowHeight: width <= 480 ? 150 : 250,
    cols: { lg: 5, md: 4, sm: 3, xs: 2, xxs: 2 }, // {lg: 1200, md: 996, sm: 768, xs: 480, xxs: 0}
  };
  const [displayProjects, setDisplayProjects] = useState([]);
  const displayProjectsRef = useRef(displayProjects);
  useEffect(() => {
    displayProjectsRef.current = displayProjects
  }, [displayProjects])
  const [projectExist, setProjectExist] = useState(true);
  const [currentBreakpoint, setCurrentBreakpoint] = useState("lg");

  useEffect(() => { // store rgl on component unmount
    return () => {
      if(loggedInStatus.loggedIn === "LOGGED_IN") {
        const layout = { ["layout"]: {lg: displayProjectsRef.current.map(project => project.rgl)}}
        fetch(`/api/v1/sessions/${loggedInStatus.user.id}`, options('PATCH', {react_grid_layout_data: JSON.stringify(layout)}))
        .then(r => r.json())
        .then(data => {
          console.log("User React Grid Layout Updated", data)
        })
      }
    }
  }, [])
  useEffect(() => {
    (async () => {
      if(loggedInStatus.loggedIn === "LOGGED_IN") {
        let response = await fetch("/api/v1/logged_in")
        const data = await response.json()
        const rgl = data.user.react_grid_layout_data || JSON.stringify({layout: {lg: []}})
        const originalLayout = JSON.parse(JSON.stringify(getFromDB("layout", rgl)))
      
        response = await fetch(`/api/v1/projects`)
        const list = await response.json()
        const allProjects = list.flat();
        
        if(allProjects.length === 0) {
          setProjectExist(false) // Required if I don't want to display 'no projects' while processing.
        } else {
          allProjects.map(project => {
            project["rgl"] = originalLayout.lg.find(layout => layout.i === `${project.id}${project.tool_name}`) || {
              x: _.random(0, 5),
              y: Infinity,
              w: 1,
              h: 1,
              i: `${project.id}${project.tool_name}`
            };
          })
          sortNewestToOldest(allProjects).map((project, index) => {
            if(index < maxProject) {
              project["can_update"] = true
            } else {
              project["can_update"] = false
            }
          })
          // console.log(allProjects)
          setDisplayProjects(allProjects);
        }
      }
    })();
  }, []);

  function sortNewestToOldest(array) {
    const sortProperty = 'updated_at';
    const sorted = array.sort((a, b) => new Date(b[sortProperty]) - new Date(a[sortProperty]));
    return sorted
  }

  function generateDOM() {
    return displayProjects.map(project => (
      <Project
        del={(e) => handleDeleteProject(project, e)}
        user={loggedInStatus}
        key={`${project.id}${project.tool_name}`}
        project={project}
      />
    ));
  }
  function getFromDB(key, rgl) {
    let ls = {};
    ls = JSON.parse(rgl) || {layout: {lg: []}};
    return ("lg" in ls[key]) ? ls[key] : {lg: []} ;
  }
  const handleDeleteProject = (project, e) => {
    e.stopPropagation()
    fetch(`/api/v1/${project.tool_name}/${project.id}`, options('DELETE', null))
    .then(r => r .json())
    .then(data => {
      console.log(`${project.tool_name} Deleted`, data)
      successToast("Project Deleted Successfuly", 3000, "alert", "👌")
      updateUser()
      const newProjectList = displayProjects.filter(proj => proj.rgl.i !== project.rgl.i)
      setDisplayProjects(newProjectList)
    })
  }
  const onBreakpointChange = breakpoint => {
    setCurrentBreakpoint(breakpoint)
  };
  const onLayoutChange = (layout, layouts) => {
    for(let i=0; i<displayProjects.length; i++) {
      displayProjects[i].rgl = layouts.lg[i]
    }
    setDisplayProjects(displayProjects)
  };

  function handleLayout() {
    const myLayout = displayProjects.map(project => project.rgl)
    return {lg: myLayout}
  }

  return (
    <motion.div className="user-main" initial="initial" animate="in" exit="out" variants={pageVariants} transition={pageTransition}>
      {displayProjects.length > 0 && 
        <ResponsiveReactGridLayout
          {...defaultProps}
          layouts={handleLayout()}
          onBreakpointChange={(breakpoint) => onBreakpointChange(breakpoint)}
          onLayoutChange={(layout, layouts) => onLayoutChange(layout, layouts)}
          compactType="vertical"
        >
          {generateDOM()}
        </ResponsiveReactGridLayout>
      }
      {!projectExist &&
        <div
          onClick={() => history.push(`/`)} 
          style={{cursor: "pointer"}}
          className="no-project"
        >
          <h1>No Project Saved</h1>
          <h1>Click Here and Start a New Project!</h1>
        </div>
      } 
    </motion.div>
  );
}

export default UserShow;
